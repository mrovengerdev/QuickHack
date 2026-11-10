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
    return component.GetEntity() as GameObject;
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
