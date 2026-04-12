/// <reference types="vite/client" />

declare const __APP_VERSION__: string;

interface Window {
  __termexCaptureContext?: (sessionId: string) => import("./types/aiContext").TerminalContext | null;
  __termexCaptureBuffer?: (sessionId: string, lines: number) => string;
}
