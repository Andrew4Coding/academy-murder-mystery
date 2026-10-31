export const REFERENCE_OFFSET = 978307200;

export type Clock = () => number;

export const systemClock: Clock = () => Date.now() / 1000 - REFERENCE_OFFSET;

export const toUnix = (reference: number): number => reference + REFERENCE_OFFSET;
