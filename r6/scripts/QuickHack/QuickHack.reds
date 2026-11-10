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
    if AbsF(angleDistance.Yaw) > 15.00 || AbsF(angleDistance.Pitch) > 15.00 {
      return null;
    };
    return component.GetEntity() as GameObject;
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

public class QuickHackIcons extends IScriptable {
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

  public final static func Slot(command: ref<QuickhackData>, slot: Int32, x: Float, y: Float) -> ref<inkCanvas> {
    let canvas: ref<inkCanvas>;
    let image: ref<inkImage>;
    let record: wref<UIIcon_Record>;
    let margin: inkMargin;
    let canvasName: CName;
    let imageName: CName;
    if !IsDefined(command) || !TDBID.IsValid(command.m_icon) {
      return null;
    };
    record = TweakDBInterface.GetUIIconRecord(command.m_icon);
    if !IsDefined(record) {
      return null;
    };
    canvas = new inkCanvas();
    canvasName = StringToName("qhslot" + IntToString(slot));
    canvas.SetName(canvasName);
    canvas.SetAnchor(inkEAnchor.TopLeft);
    canvas.SetSize(new Vector2(56.00, 56.00));
    margin.left = x;
    margin.top = y;
    margin.right = 0.00;
    margin.bottom = 0.00;
    canvas.SetMargin(margin);
    canvas.SetVisible(true);
    image = new inkImage();
    imageName = StringToName("qhicon" + IntToString(slot));
    image.SetName(imageName);
    image.SetAnchor(inkEAnchor.TopLeft);
    image.SetSize(new Vector2(56.00, 56.00));
    image.SetFitToContent(false);
    image.SetVisible(true);
    image.Reparent(canvas, -1);
    image.SetAtlasResource(record.AtlasResourcePath());
    image.SetTexturePart(record.AtlasPartName());
    InkImageUtils.RequestSetImage(null, image, command.m_icon);
    return canvas;
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
