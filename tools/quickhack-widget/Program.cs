using System.Security.Cryptography;
using System.Text;
using WolvenKit.Common;
using WolvenKit.Common.FNV1A;
using WolvenKit.Core.CRC;
using WolvenKit.Core.Extensions;
using WolvenKit.Core.Interfaces;
using WolvenKit.RED4.Archive;
using WolvenKit.RED4.Archive.Buffer;
using WolvenKit.RED4.Archive.CR2W;
using WolvenKit.RED4.Archive.IO;
using WolvenKit.RED4.Types;
using static WolvenKit.RED4.Types.Enums;

const string DepotRel = "quickhack/hud/slot.inkwidget";
const string AtlasPath = @"base\gameplay\gui\common\icons\quickhacks_icons.inkatlas";
const string StylePath = @"base\gameplay\gui\common\main_colors.inkstyle";

if (args.Length < 2)
{
    Console.Error.WriteLine("usage: quickhack-widget <out-inkwidget> <out-archive>");
    return 1;
}

var widgetPath = Path.GetFullPath(args[0]);
var archivePath = Path.GetFullPath(args[1]);

var canvas = new inkCanvasWidget
{
    Name = "Slot",
    Visible = true,
    Opacity = 1.0f,
    FitToContent = false,
    Size = new Vector2 { X = 56f, Y = 56f },
    Layout = new inkWidgetLayout
    {
        Padding = new inkMargin(),
        Margin = new inkMargin(),
        Anchor = inkEAnchor.TopLeft,
        AnchorPoint = new Vector2 { X = 0f, Y = 0f },
        SizeCoefficient = 1.0f
    }
};

var image = new inkImageWidget
{
    Name = "icon",
    Visible = true,
    Opacity = 1.0f,
    FitToContent = false,
    Size = new Vector2 { X = 56f, Y = 56f },
    Layout = new inkWidgetLayout
    {
        Padding = new inkMargin(),
        Margin = new inkMargin(),
        Anchor = inkEAnchor.Fill,
        AnchorPoint = new Vector2 { X = 0.5f, Y = 0.5f },
        SizeCoefficient = 1.0f
    },
    ContentHAlign = inkEHorizontalAlign.Center,
    ContentVAlign = inkEVerticalAlign.Center,
    TextureAtlas = new CResourceAsyncReference<inkTextureAtlas>(AtlasPath),
    ParentWidget = canvas
};

var children = canvas.Children?.GetValue() as inkMultiChildren;
if (children is null)
{
    children = new inkMultiChildren();
    canvas.Children = children;
}
children.Children.Add(image);

var instance = new inkWidgetLibraryItemInstance { RootWidget = canvas };

inkETextureResolution? rootRes = null;
try
{
    var resNames = Enum.GetNames(typeof(inkETextureResolution));
    Console.WriteLine("inkETextureResolution: " + string.Join(", ", resNames));
    if (Enum.TryParse(typeof(inkETextureResolution), "UltraHD_4K_2160p", out var hd) ||
        Enum.TryParse(typeof(inkETextureResolution), "HD_1080p", out hd))
    {
        rootRes = (inkETextureResolution)hd!;
        instance.RootResolution = rootRes.Value;
    }
}
catch (Exception ex)
{
    Console.WriteLine("resolution enum skip: " + ex.Message);
}

var packageFile = new CR2WFile { RootChunk = instance };
packageFile.MetaData.FileName = "package";

var item = new inkWidgetLibraryItem
{
    Name = "Slot",
    Package = new SharedDataBuffer { Data = new CR2WWrapper { File = packageFile } },
    PackageData = new DataBuffer { Data = new RedPackage { Chunks = new List<RedBaseClass> { instance } } }
};

var library = new inkWidgetLibraryResource();
library.LibraryItems.Add(item);
library.RootDefinitionIndex = 0;
library.ExternalDependenciesForInternalItems.Add(new CResourceAsyncReference<CResource>(AtlasPath));
library.ExternalDependenciesForInternalItems.Add(new CResourceAsyncReference<CResource>(StylePath));

try
{
    var names = Enum.GetNames(typeof(inkWidgetResourceVersion));
    Console.WriteLine("inkWidgetResourceVersion: " + string.Join(", ", names));
    if (names.Length > 0)
    {
        library.Version = (inkWidgetResourceVersion)Enum.Parse(typeof(inkWidgetResourceVersion), names[^1]);
    }
}
catch (Exception ex)
{
    Console.WriteLine("version enum skip: " + ex.Message);
}

if (rootRes is not null)
{
    library.RootResolution = rootRes.Value;
}

var cr2w = new CR2WFile { RootChunk = library };
cr2w.MetaData.FileName = DepotRel.Replace('/', '\\');

Directory.CreateDirectory(Path.GetDirectoryName(widgetPath)!);
using (var fs = File.Create(widgetPath))
using (var writer = new CR2WWriter(fs) { LoggerService = new ConsoleLogger() })
{
    writer.WriteFile(cr2w);
}

var widgetBytes = File.ReadAllBytes(widgetPath);
Console.WriteLine($"wrote {widgetPath} ({widgetBytes.Length} bytes)");
if (widgetBytes.Length < 4 || BitConverter.ToUInt32(widgetBytes, 0) != CR2WFile.MAGIC)
{
    Console.Error.WriteLine("inkwidget does not start with CR2W magic");
    return 2;
}

Directory.CreateDirectory(Path.GetDirectoryName(archivePath)!);
WriteUncompressedArchive(widgetBytes, DepotRel, archivePath);
Console.WriteLine($"wrote {archivePath} ({new FileInfo(archivePath).Length} bytes)");
return 0;

static void WriteUncompressedArchive(byte[] fileBytes, string depotRel, string archivePath)
{
    var sanitized = ResourcePath.SanitizePath(depotRel);
    var hash = FNV1A64HashAlgorithm.HashString(sanitized);
    var sha1 = SHA1.HashData(fileBytes);

    using var ms = new MemoryStream();
    using var bw = new BinaryWriter(ms, Encoding.UTF8, leaveOpen: true);

    var header = new Header { Version = 12 };
    WriteHeader(bw, header);
    bw.Write(new byte[132]);

    var paths = new List<string> { sanitized };
    var footerStart = bw.BaseStream.Position;
    new LxrsFooter(paths).Write(bw);
    var customDataLength = bw.BaseStream.Position - Header.EXTENDED_SIZE;

    var dataOffset = (ulong)bw.BaseStream.Position;
    bw.Write(fileBytes);
    var size = (uint)fileBytes.Length;

    bw.PadUntilPage();
    var indexPosition = (ulong)bw.BaseStream.Position;

    using var table = new MemoryStream();
    using var tw = new BinaryWriter(table);
    tw.Write(1u); // file entries
    tw.Write(1u); // segments
    tw.Write(0u); // dependencies

    tw.Write(hash);
    tw.Write(DateTime.Now.ToFileTime());
    tw.Write(0u); // NumInlineBufferSegments
    tw.Write(0u); // SegmentsStart
    tw.Write(1u); // SegmentsEnd
    tw.Write(0u); // ResourceDependenciesStart
    tw.Write(0u); // ResourceDependenciesEnd
    tw.Write(sha1);

    tw.Write(dataOffset);
    tw.Write(size); // zsize == size (uncompressed)
    tw.Write(size);

    var tableBytes = table.ToArray();
    bw.Write(8u); // FileTableOffset
    bw.Write((uint)(tableBytes.Length + 8));
    bw.Write(Crc64.Compute(tableBytes));
    bw.Write(tableBytes);

    var indexSize = (uint)(bw.BaseStream.Position - (long)indexPosition);
    bw.PadUntilPage();
    var filesize = (ulong)bw.BaseStream.Position;

    header.IndexPosition = indexPosition;
    header.IndexSize = indexSize;
    header.Filesize = filesize;
    bw.BaseStream.Seek(0, SeekOrigin.Begin);
    WriteHeader(bw, header);
    bw.Write(customDataLength);
    bw.Flush();

    File.WriteAllBytes(archivePath, ms.ToArray());
    Console.WriteLine($"archive hash={hash:X16} path={sanitized} customDataLength={customDataLength} offset={dataOffset}");
}

static void WriteHeader(BinaryWriter bw, Header header)
{
    bw.Write(Header.MAGIC);
    bw.Write(header.Version);
    bw.Write(header.IndexPosition);
    bw.Write(header.IndexSize);
    bw.Write(header.DebugPosition);
    bw.Write(header.DebugSize);
    bw.Write(header.Filesize);
}

sealed class ConsoleLogger : ILoggerService
{
    public LoggerVerbosity LoggerVerbosity { get; private set; } = LoggerVerbosity.Normal;
    public void Info(string s) => Console.WriteLine(s);
    public void Warning(string s) => Console.WriteLine("warn: " + s);
    public void Error(string msg) => Console.Error.WriteLine("error: " + msg);
    public void Success(string msg) => Console.WriteLine(msg);
    public void Debug(string msg) => Console.WriteLine("debug: " + msg);
    public void Error(Exception exception) => Console.Error.WriteLine(exception);
    public void SetLoggerVerbosity(LoggerVerbosity verbosity) => LoggerVerbosity = verbosity;
}
