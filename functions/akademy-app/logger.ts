export interface LogContext {
  correlationId?: string;
  userId?: string;
  userLevel?: number;
  endpoint?: string;
  [key: string]: unknown;
}

export enum LogLevel {
  DEBUG = "debug",
  INFO = "info",
  WARN = "warn",
  ERROR = "error",
}

class Logger {
  private log(level: LogLevel, message: string, context?: LogContext): void {
    const timestamp = new Date().toISOString();
    const logEntry = {
      timestamp,
      level,
      message,
      ...context,
    };

    console.log(JSON.stringify(logEntry));
  }

  debug(message: string, context?: LogContext): void {
    this.log(LogLevel.DEBUG, message, context);
  }

  info(message: string, context?: LogContext): void {
    this.log(LogLevel.INFO, message, context);
  }

  warn(message: string, context?: LogContext): void {
    this.log(LogLevel.WARN, message, context);
  }

  error(message: string, context?: LogContext & { error?: Error }): void {
    const errorContext = context?.error
      ? {
        ...context,
        errorMessage: context.error.message,
        errorStack: context.error.stack,
      }
      : context;

    this.log(LogLevel.ERROR, message, errorContext);
  }
}

export const logger = new Logger();
