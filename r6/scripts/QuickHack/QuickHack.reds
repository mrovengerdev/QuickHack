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
  public final static func Target(player: ref<GameObject>) -> ref<GameObject> {
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
    if AbsF(angleDistance.Yaw) > 12.00 || AbsF(angleDistance.Pitch) > 12.00 {
      return null;
    };
    return component.GetEntity() as GameObject;
  }

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

  public final static func AngleText(player: ref<GameObject>) -> String {
    let angleDistance: EulerAngles;
    let component: wref<TargetingComponent>;
    let searchQuery: TargetSearchQuery;
    if !IsDefined(player) {
      return "";
    };
    TargetSearchQuery.SetComponentFilter(searchQuery, TargetComponentFilterType.QuickHack);
    searchQuery.searchFilter = TSF_Quickhackable();
    searchQuery.maxDistance = SNameplateRangesData.GetMaxDisplayRange();
    component = GameInstance.GetTargetingSystem(player.GetGame()).GetComponentClosestToCrosshair(player, angleDistance, searchQuery) as TargetingComponent;
    if !IsDefined(component) {
      return "";
    };
    return "yaw=" + FloatToStringPrec(angleDistance.Yaw, 2) + " pitch=" + FloatToStringPrec(angleDistance.Pitch, 2);
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

  public final static func Facing(player: ref<GameObject>, entity: ref<GameObject>) -> Float {
    let origin: Vector4;
    let forward: Vector4;
    let target: Vector4;
    let dx: Float;
    let dy: Float;
    let dz: Float;
    let fx: Float;
    let fy: Float;
    let fz: Float;
    let dLen: Float;
    let fLen: Float;
    if !IsDefined(player) || !IsDefined(entity) {
      return -2.00;
    };
    GameInstance.GetTargetingSystem(player.GetGame()).GetDefaultCrosshairData(player, origin, forward);
    target = entity.GetWorldPosition();
    dx = target.X - origin.X;
    dy = target.Y - origin.Y;
    dz = target.Z - origin.Z;
    fx = forward.X;
    fy = forward.Y;
    fz = forward.Z;
    fLen = SqrtF(fx * fx + fy * fy + fz * fz);
    dLen = SqrtF(dx * dx + dy * dy + dz * dz);
    if fLen < 0.05 || dLen < 0.25 {
      return -2.00;
    };
    return (fx * dx + fy * dy + fz * dz) / (fLen * dLen);
  }
}


public class QuickHackIcons extends IScriptable {
  public final static func IconRecord(command: ref<QuickhackData>) -> wref<UIIcon_Record> {
    let record: wref<UIIcon_Record>;
    if !IsDefined(command) || !TDBID.IsValid(command.m_icon) {
      return null;
    };
    record = TweakDBInterface.GetUIIconRecord(command.m_icon);
    if IsDefined(record) {
      return record;
    };
    return null;
  }

  public final static func DebugOf(command: ref<QuickhackData>) -> String {
    let record: wref<UIIcon_Record> = QuickHackIcons.IconRecord(command);
    if !IsDefined(command) {
      return "no-command";
    };
    if !TDBID.IsValid(command.m_icon) {
      return "icon-id-invalid";
    };
    if !IsDefined(record) {
      return "no-uiicon-record";
    };
    return ResRef.ToString(record.AtlasResourcePath()) + " part=" + NameToString(record.AtlasPartName());
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

  public final static func AtlasPathOf(command: ref<QuickhackData>) -> String {
    if !IsDefined(command) {
      return "";
    };
    return QuickHackIcons.AtlasPath(command.m_icon);
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

  public final static func Attach(parent: wref<inkCompoundWidget>, command: ref<QuickhackData>, slot: Int32, x: Float, y: Float) -> Bool {
    let canvas: ref<inkCanvas>;
    let image: ref<inkImage>;
    let record: wref<UIIcon_Record>;
    let margin: inkMargin;
    let canvasName: CName;
    let imageName: CName;
    let old: wref<inkWidget>;
    if !IsDefined(parent) || !IsDefined(command) || !TDBID.IsValid(command.m_icon) {
      return false;
    };
    record = TweakDBInterface.GetUIIconRecord(command.m_icon);
    if !IsDefined(record) {
      return false;
    };
    canvasName = StringToName("qhslot" + IntToString(slot));
    old = parent.GetWidget(canvasName);
    if IsDefined(old) {
      parent.RemoveChild(old);
    };
    canvas = new inkCanvas();
    canvas.SetName(canvasName);
    canvas.SetAnchor(inkEAnchor.TopLeft);
    canvas.SetSize(new Vector2(56.00, 56.00));
    margin.left = x;
    margin.top = y;
    margin.right = 0.00;
    margin.bottom = 0.00;
    canvas.SetMargin(margin);
    canvas.Reparent(parent, -1);
    canvas.SetVisible(true);
    image = new inkImage();
    imageName = StringToName("qhicon" + IntToString(slot));
    image.SetName(imageName);
    image.SetAnchor(inkEAnchor.Fill);
    image.SetAnchorPoint(new Vector2(0.50, 0.50));
    image.SetSize(new Vector2(56.00, 56.00));
    image.SetFitToContent(false);
    image.SetVisible(true);
    image.Reparent(canvas, -1);
    image.SetAtlasResource(record.AtlasResourcePath());
    image.SetTexturePart(record.AtlasPartName());
    InkImageUtils.RequestSetImage(null, image, command.m_icon);
    return true;
  }

  public final static func Paint(image: wref<inkImage>, command: ref<QuickhackData>) -> Bool {
    return QuickHackIcons.PaintFor(image, command, null);
  }

  public final static func PaintFor(image: wref<inkImage>, command: ref<QuickhackData>, owner: wref<IScriptable>) -> Bool {
    let record: wref<UIIcon_Record> = QuickHackIcons.IconRecord(command);
    if !IsDefined(image) || !IsDefined(record) {
      return false;
    };
    image.SetVisible(true);
    image.SetFitToContent(false);
    image.SetSize(new Vector2(56.00, 56.00));
    image.SetAtlasResource(record.AtlasResourcePath());
    image.SetTexturePart(record.AtlasPartName());
    if IsDefined(owner) && TDBID.IsValid(command.m_icon) {
      InkImageUtils.RequestSetImage(owner, image, command.m_icon);
    };
    return true;
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
