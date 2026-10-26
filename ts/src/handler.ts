/** Ephemeral host guards; callbacks also check after every await and before effects. */
import type { OpenQrLink } from "./types.js";

export type OpenQrScanContext =
  | "general"
  | "pay"
  | "network"
  | "connect"
  | "bookingCheck"
  | "ticketCheck"
  | "walletConnect";
export type OpenQrHandling =
  | "handled"
  | "cancelled"
  | "obsolete"
  | "unsupported";
export type OpenQrHandler = (
  link: OpenQrLink,
  invocation: OpenQrInvocation,
) => Promise<OpenQrHandling>;
export interface OpenQrInvocationOptions {
  readonly context: OpenQrScanContext;
  readonly isCurrent: () => boolean;
  readonly isCancelled: () => boolean;
}
export class OpenQrInvocation implements OpenQrInvocationOptions {
  readonly context: OpenQrScanContext;
  readonly isCurrent: () => boolean;
  readonly isCancelled: () => boolean;

  constructor(options: OpenQrInvocationOptions) {
    this.context = options.context;
    this.isCurrent = options.isCurrent;
    this.isCancelled = options.isCancelled;
    Object.freeze(this);
  }

  get interruption(): OpenQrHandling | null {
    return !this.isCurrent()
      ? "obsolete"
      : this.isCancelled()
        ? "cancelled"
        : null;
  }

  /** Checks before dispatch and after completion; errors reach the host UI boundary. */
  async run(link: OpenQrLink, handler: OpenQrHandler): Promise<OpenQrHandling> {
    const stopped = this.interruption;
    if (stopped) return stopped;
    const outcome = await handler(link, this);
    return this.interruption ?? outcome;
  }
}
