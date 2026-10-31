export type RuleErrorKind =
  | "invalidSetup" | "gameEnded" | "unknownFamily" | "familyNotAlive" | "notWerewolf" | "notVillager"
  | "wrongPhase" | "cooldownActive" | "sabotageAlreadyActive" | "noActiveSabotage" | "invalidVoteTarget"
  | "notDead" | "skipNotRequested" | "timerFinished" | "sabotageActive";

const MESSAGES: Record<RuleErrorKind, string> = {
  invalidSetup: "",
  gameEnded: "The game has ended.",
  unknownFamily: "Unknown family.",
  familyNotAlive: "That family is no longer in the game.",
  notWerewolf: "Only werewolf families can do that.",
  notVillager: "That family can't be targeted.",
  wrongPhase: "That isn't allowed right now.",
  skipNotRequested: "Most families haven't voted to skip yet.",
  timerFinished: "That timer already finished.",
  cooldownActive: "Still on cooldown.",
  sabotageAlreadyActive: "A sabotage is already running.",
  noActiveSabotage: "There's no sabotage to resolve.",
  invalidVoteTarget: "That family can't receive votes.",
  notDead: "That family is still in the game.",
  sabotageActive: "No meetings while a sabotage is active."
};

export class RuleError extends Error {
  constructor(readonly kind: RuleErrorKind, reason?: string) {
    super(kind === "invalidSetup" ? (reason ?? "") : MESSAGES[kind]);
  }
}

export type HostErrorKind =
  | "notSignedIn" | "unsupportedVersion" | "invalidCredential" | "tooManyAttempts" | "nameRequired"
  | "familyFull" | "gameAlreadyStarted" | "unknownDevice" | "notAPlayer" | "invalidName" | "photoTooLarge"
  | "invalidImage" | "notNearBody" | "setup" | "notNearby" | "notOC" | "wrongStation" | "notInGame"
  | "familyHasMembers" | "notActiveHost" | "unknownBooth";

const HOST_MESSAGES: Record<HostErrorKind, string> = {
  notSignedIn: "Join a family or enter the OC PIN first.",
  unsupportedVersion: "This app version is too old or too new for the host. Update the app.",
  invalidCredential: "That code isn't valid. Check it and try again.",
  tooManyAttempts: "Too many attempts. Wait a moment and try again.",
  nameRequired: "Enter your name to join.",
  familyFull: "That family is already full.",
  gameAlreadyStarted: "The game has already started.",
  unknownDevice: "This device isn't registered with the host any more.",
  notAPlayer: "Only players can do that.",
  notNearBody: "Get closer to the body to report it.",
  photoTooLarge: "That photo is too large.",
  invalidImage: "That file isn't an image the map can use.",
  invalidName: "Family names need 1 to 24 characters.",
  setup: "",
  notNearby: "That family isn't close enough.",
  notOC: "Only organisers can do that.",
  wrongStation: "This sabotage is handled at a different station.",
  notInGame: "There's no game running.",
  familyHasMembers: "That family already has members.",
  unknownBooth: "That booth no longer exists.",
  notActiveHost: "The game is hosted elsewhere right now. Reconnect to the active host."
};

export class HostError extends Error {
  constructor(readonly kind: HostErrorKind, reason?: string) {
    super(kind === "setup" ? (reason ?? "") : HOST_MESSAGES[kind]);
  }
}
