@addMethod(ScriptedPuppet)
public final func QuickHack_FillCommands() -> array<ref<QuickhackData>> {
  let actionRecords: array<wref<ObjectAction_Record>>;
  let commands: array<ref<QuickhackData>>;
  let context: GetActionsContext;
  let puppetActions: array<ref<PuppetAction>>;
  context = this.GetPS().GenerateContext(gamedeviceRequestType.Remote, Device.GetInteractionClearance(), GameInstance.GetPlayerSystem(this.GetGame()).GetLocalPlayerControlledGameObject(), this.GetEntityID());
  this.GetRecord().ObjectActions(actionRecords);
  this.GetPS().GetAllChoices(actionRecords, context, puppetActions);
  this.TranslateChoicesIntoQuickSlotCommands(puppetActions, commands);
  return commands;
}

@addMethod(Device)
public final func QuickHack_FillCommands() -> array<ref<QuickhackData>> {
  let actions: array<ref<DeviceAction>>;
  let commands: array<ref<QuickhackData>>;
  let context: GetActionsContext;
  context = this.GetDevicePS().GenerateContext(gamedeviceRequestType.Remote, Device.GetInteractionClearance(), GameInstance.GetPlayerSystem(this.GetGame()).GetLocalPlayerControlledGameObject(), this.GetEntityID());
  this.GetDevicePS().GetRemoteActions(actions, context);
  if this.m_isQhackUploadInProgerss && !this.IsActionQueueEnabled() || this.IsActionQueueFull() {
    ScriptableDeviceComponentPS.SetActionsInactiveAll(actions, "LocKey#7020");
  };
  QuickHackableHelper.TranslateActionsIntoQuickSlotCommands(actions, commands, this, this.GetDevicePS());
  return commands;
}

@addMethod(VehicleObject)
public final func QuickHack_FillCommands() -> array<ref<QuickhackData>> {
  let actions: array<ref<DeviceAction>>;
  let commands: array<ref<QuickhackData>>;
  let context: GetActionsContext;
  context = this.GetVehiclePS().GenerateContext(gamedeviceRequestType.Remote, Device.GetInteractionClearance(), GameInstance.GetPlayerSystem(this.GetGame()).GetLocalPlayerControlledGameObject(), this.GetEntityID());
  this.GetVehiclePS().GetRemoteActions(actions, context);
  if this.m_isQhackUploadInProgress && !this.IsActionQueueEnabled() || this.IsActionQueueFull() {
    ScriptableDeviceComponentPS.SetActionsInactiveAll(actions, "LocKey#7020");
  };
  if this.IsActionQueueEnabled() {
    QuickHackableQueueHelper.CheckAndSetInactivityReasonForVehicleActions(actions, this.m_currentlyUploadingAction);
  };
  QuickHackableHelper.TranslateActionsIntoQuickSlotCommands(actions, commands, this, this.GetVehiclePS());
  return commands;
}

public class QuickHackCrosshair extends IScriptable {
  public final static func Closest(player: ref<GameObject>) -> ref<GameObject> {
    let angleDistance: EulerAngles;
    let component: wref<TargetingComponent>;
    let searchQuery: TargetSearchQuery;
    if !IsDefined(player) {
      return null;
    };
    TargetSearchQuery.SetComponentFilter(searchQuery, TargetComponentFilterType.QuickHack);
    searchQuery.searchFilter = TSF_Quickhackable();
    searchQuery.maxDistance = SNameplateRangesData.GetMaxDisplayRange();
    component = GameInstance.GetTargetingSystem(player.GetGame()).GetComponentClosestToCrosshair(player, angleDistance, searchQuery) as TargetingComponent;
    if !IsDefined(component) {
      return null;
    };
    return component.GetEntity() as GameObject;
  }

  public final static func ClosestAngle(player: ref<GameObject>) -> Float {
    let angleDistance: EulerAngles;
    let component: wref<TargetingComponent>;
    let searchQuery: TargetSearchQuery;
    if !IsDefined(player) {
      return 999.00;
    };
    TargetSearchQuery.SetComponentFilter(searchQuery, TargetComponentFilterType.QuickHack);
    searchQuery.searchFilter = TSF_Quickhackable();
    searchQuery.maxDistance = SNameplateRangesData.GetMaxDisplayRange();
    component = GameInstance.GetTargetingSystem(player.GetGame()).GetComponentClosestToCrosshair(player, angleDistance, searchQuery) as TargetingComponent;
    if !IsDefined(component) {
      return 999.00;
    };
    return MaxF(AbsF(angleDistance.Yaw), AbsF(angleDistance.Pitch));
  }
}

public class QuickHackAim extends IScriptable {
  public final static func LookAt(player: ref<GameObject>) -> ref<GameObject> {
    let looked: ref<GameObject>;
    if !IsDefined(player) {
      return null;
    };
    looked = GameInstance.GetTargetingSystem(player.GetGame()).GetLookAtObject(player, true, true);
    if IsDefined(looked) {
      return looked;
    };
    return GameInstance.GetTargetingSystem(player.GetGame()).GetLookAtObject(player, true, false);
  }
}

public class QuickHackIconLoad extends IScriptable {
  public let image: wref<inkImage>;
  public let part: CName;

  public func OnIconLoaded() -> Void {
    if IsDefined(this.image) {
      this.image.SetVisible(true);
      this.image.SetOpacity(1.00);
      this.image.SetTexturePart(this.part);
    };
  }
}

public class QuickHackIcons extends IScriptable {
  public final static func RequestIcon(image: wref<inkImage>, iconID: TweakDBID, owner: wref<IScriptable>) -> Void {
    let iconRef: ref<UIIconReference>;
    let load: ref<QuickHackIconLoad>;
    let record: wref<UIIcon_Record>;
    let controller: wref<inkGameController>;
    if !IsDefined(image) || !TDBID.IsValid(iconID) {
      return;
    };
    iconRef = new UIIconReference();
    iconRef.iconID = iconID;
    load = new QuickHackIconLoad();
    load.image = image;
    record = TweakDBInterface.GetUIIconRecord(iconID);
    if IsDefined(record) {
      load.part = record.AtlasPartName();
    };
    if IsDefined(owner) {
      controller = owner as inkGameController;
      if IsDefined(controller) {
        InkImageUtils.RequestSetImage(controller, image, iconID);
      };
    };
    image.RequestSetImage(iconRef, load, n"OnIconLoaded");
  }

  public final static func DebugOf(command: ref<QuickhackData>) -> String {
    let path: String;
    let part: String;
    if !IsDefined(command) {
      return "no-command";
    };
    if !TDBID.IsValid(command.m_icon) {
      return "icon-id-invalid";
    };
    path = QuickHackIcons.AtlasPath(command.m_icon);
    part = QuickHackIcons.PartName(command.m_icon);
    if StrLen(path) == 0 {
      return "no-uiicon-record";
    };
    return path + " part=" + part;
  }

  public final static func AtlasPath(iconID: TweakDBID) -> String {
    let record: wref<UIIcon_Record> = TweakDBInterface.GetUIIconRecord(iconID);
    if !TDBID.IsValid(iconID) || !IsDefined(record) {
      return "";
    };
    return ResRef.ToString(record.AtlasResourcePath());
  }

  public final static func PartName(iconID: TweakDBID) -> String {
    let record: wref<UIIcon_Record> = TweakDBInterface.GetUIIconRecord(iconID);
    if !TDBID.IsValid(iconID) || !IsDefined(record) {
      return "";
    };
    return NameToString(record.AtlasPartName());
  }

  public final static func PartNameOf(command: ref<QuickhackData>) -> String {
    if !IsDefined(command) {
      return "";
    };
    return QuickHackIcons.PartName(command.m_icon);
  }

  public final static func CostOf(command: ref<QuickhackData>) -> Int32 {
    if !IsDefined(command) {
      return -1;
    };
    if command.m_cost > 0 {
      return command.m_cost;
    };
    if IsDefined(command.m_action) {
      let actionCost: Int32 = command.m_action.GetCost();
      if actionCost > 0 {
        return actionCost;
      };
    };
    if command.m_costRaw > 0 {
      return command.m_costRaw;
    };
    return command.m_cost;
  }

  public final static func CanAfford(command: ref<QuickhackData>, player: ref<GameObject>) -> Bool {
    let cost: Int32;
    let memory: Float;
    let health: Float;
    let healthCost: Float;
    if !IsDefined(command) || !IsDefined(player) {
      return false;
    };
    cost = QuickHackIcons.CostOf(command);
    if cost <= 0 {
      return true;
    };
    memory = GameInstance.GetStatPoolsSystem(player.GetGame()).GetStatPoolValue(player.GetEntityID(), gamedataStatPoolType.Memory, false);
    if memory >= Cast<Float>(cost) {
      return true;
    };
    if !StatusEffectSystem.ObjectHasStatusEffect(player, t"BaseStatusEffect.Intelligence_Central_Milestone_3_Overclock_Buff") {
      return false;
    };
    healthCost = GameInstance.GetStatsSystem(player.GetGame()).GetStatValue(player.GetEntityID(), gamedataStatType.OverclockedStateHealthCost) * (Cast<Float>(cost) - memory);
    health = GameInstance.GetStatPoolsSystem(player.GetGame()).GetStatPoolValue(player.GetEntityID(), gamedataStatPoolType.Health, false);
    return health - healthCost > 0.00;
  }

  public final static func TitleOf(command: ref<QuickhackData>) -> String {
    let title: String;
    let localized: String;
    let part: String;
    if !IsDefined(command) {
      return "";
    };
    title = command.m_title;
    if StrLen(title) == 0 {
      title = command.m_titleAlternative;
    };
    if StrLen(title) > 0 {
      localized = GetLocalizedText(title);
      if StrLen(localized) > 0 {
        return localized;
      };
      return title;
    };
    if NotEquals(command.m_iconCategory, n"") && NotEquals(command.m_iconCategory, n"None") {
      return NameToString(command.m_iconCategory);
    };
    part = QuickHackIcons.PartNameOf(command);
    if StrLen(part) > 0 && NotEquals(part, "None") {
      return part;
    };
    return "";
  }

  public final static func IsPlaceholder(command: ref<QuickhackData>) -> Bool {
    let title: String;
    if !IsDefined(command) {
      return true;
    };
    if command.m_noQuickhackData {
      return true;
    };
    title = QuickHackIcons.TitleOf(command);
    if StrFindFirst(title, "NO COMPATIBLE") >= 0 || StrFindFirst(title, "No Compatible") >= 0 || StrFindFirst(title, "no compatible") >= 0 {
      return true;
    };
    if StrFindFirst(command.m_title, "NO COMPATIBLE") >= 0 || StrFindFirst(command.m_titleAlternative, "NO COMPATIBLE") >= 0 {
      return true;
    };
    return false;
  }

  public final static func MakeBarOn(root: wref<inkCompoundWidget>, width: Float, height: Float, bottom: Float) -> wref<inkCanvas> {
    let existing: wref<inkWidget>;
    let bar: ref<inkCanvas>;
    let margin: inkMargin;
    if !IsDefined(root) {
      return null;
    };
    existing = root.GetWidget(n"quickhack_bar");
    if IsDefined(existing) {
      root.RemoveChild(existing);
    };
    bar = new inkCanvas();
    bar.SetName(n"quickhack_bar");
    bar.SetAnchor(inkEAnchor.BottomCenter);
    bar.SetAnchorPoint(new Vector2(0.50, 1.00));
    bar.SetSize(new Vector2(width, height));
    margin.left = 0.00;
    margin.top = 0.00;
    margin.right = 0.00;
    margin.bottom = bottom;
    bar.SetMargin(margin);
    bar.SetVisible(false);
    bar.Reparent(root, -1);
    return bar;
  }

  public final static func MakeBar(controller: wref<inkGameController>, width: Float, height: Float, bottom: Float) -> wref<inkCanvas> {
    if !IsDefined(controller) {
      return null;
    };
    return QuickHackIcons.MakeBarOn(controller.GetRootCompoundWidget(), width, height, bottom);
  }

  public final static func TintIcon(widget: wref<inkWidget>, red: Bool) -> Bool {
    let image: wref<inkImage>;
    let path: CName;
    if !IsDefined(widget) {
      return false;
    };
    path = n"MainColors.Blue";
    if red {
      path = n"MainColors.Red";
    };
    image = QuickHackIcons.FindImage(widget);
    if !IsDefined(image) {
      return false;
    };
    image.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    image.BindProperty(n"tintColor", path);
    return true;
  }

  public final static func FindImage(widget: wref<inkWidget>) -> wref<inkImage> {
    let image: wref<inkImage>;
    let compound: wref<inkCompoundWidget>;
    let i: Int32;
    let found: wref<inkImage>;
    if !IsDefined(widget) {
      return null;
    };
    image = widget as inkImage;
    if IsDefined(image) {
      return image;
    };
    compound = widget as inkCompoundWidget;
    if IsDefined(compound) {
      i = 0;
      while i < compound.GetNumChildren() {
        found = QuickHackIcons.FindImage(compound.GetWidgetByIndex(i));
        if IsDefined(found) {
          return found;
        };
        i += 1;
      };
    };
    return null;
  }

  public final static func TrySpawnOwned(controller: wref<inkGameController>, parent: wref<inkCompoundWidget>, path: ResRef, item: CName, command: ref<QuickhackData>, slot: Int32, x: Float, y: Float, size: Float) -> Bool {
    let spawned: wref<inkWidget>;
    let image: wref<inkImage>;
    let margin: inkMargin;
    let imageName: CName;
    let old: wref<inkWidget>;
    if !IsDefined(controller) || !IsDefined(parent) || !IsDefined(command) {
      return false;
    };
    imageName = StringToName("qhicon" + IntToString(slot));
    old = parent.GetWidget(StringToName("qhspawn" + IntToString(slot)));
    if IsDefined(old) {
      parent.RemoveChild(old);
    };
    old = parent.GetWidget(imageName);
    if IsDefined(old) {
      parent.RemoveChild(old);
    };
    spawned = controller.SpawnFromExternal(parent, path, item);
    if !IsDefined(spawned) {
      return false;
    };
    image = QuickHackIcons.FindImage(spawned);
    if !IsDefined(image) {
      parent.RemoveChild(spawned);
      return false;
    };
    spawned.SetName(imageName);
    spawned.SetAnchor(inkEAnchor.TopLeft);
    spawned.SetAnchorPoint(new Vector2(0.00, 0.00));
    spawned.SetSize(new Vector2(size, size));
    spawned.SetFitToContent(false);
    spawned.SetVisible(true);
    spawned.SetOpacity(1.00);
    margin.left = x;
    margin.top = y;
    margin.right = 0.00;
    margin.bottom = 0.00;
    spawned.SetMargin(margin);
    image.SetAnchor(inkEAnchor.Fill);
    image.SetAnchorPoint(new Vector2(0.50, 0.50));
    image.SetSize(new Vector2(size, size));
    image.SetFitToContent(false);
    image.SetVisible(true);
    image.SetOpacity(1.00);
    image.SetActiveTextureType(inkTextureType.StaticTexture);
    image.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    QuickHackIcons.RequestIcon(image, command.m_icon, controller);
    return true;
  }

  public final static func LibraryReason(controller: wref<inkGameController>, parent: wref<inkCompoundWidget>, command: ref<QuickhackData>, slot: Int32, x: Float, y: Float, size: Float) -> String {
    if !IsDefined(controller) {
      return "no-controller";
    };
    if !IsDefined(parent) {
      return "no-parent";
    };
    if !IsDefined(command) || !TDBID.IsValid(command.m_icon) {
      return "no-icon-id";
    };
    if QuickHackIcons.TrySpawnOwned(controller, parent, r"quickhack\\hud\\slot.inkwidget", n"Slot", command, slot, x, y, size) {
      return "ok";
    };
    return "spawn-nil";
  }
}

public class QuickHackCast extends IScriptable {
  public final static func Execute(player: ref<GameObject>, command: ref<QuickhackData>) -> Bool {
    let cmd: ref<QuickSlotCommandUsed>;
    if !IsDefined(player) || !IsDefined(command) || command.m_noQuickhackData || command.m_isLocked || !IsDefined(command.m_action) {
      return false;
    };
    cmd = new QuickSlotCommandUsed();
    cmd.action = command.m_action;
    player.QueueEventForEntityID(command.m_actionOwner, cmd);
    return true;
  }
}
