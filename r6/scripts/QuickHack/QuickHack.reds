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

public class QuickHackIcons extends IScriptable {
  public final static func Make(iconID: TweakDBID) -> ref<UIIconReference> {
    let iconRef: ref<UIIconReference> = new UIIconReference();
    iconRef.iconID = iconID;
    return iconRef;
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
