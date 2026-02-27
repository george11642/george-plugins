import { Chat } from "@google/genai";

const sessions = new Map<string, Chat>();

export function getSession(sessionId: string): Chat | undefined {
  return sessions.get(sessionId);
}

export function setSession(sessionId: string, chat: Chat): void {
  sessions.set(sessionId, chat);
}

export function deleteSession(sessionId: string): boolean {
  return sessions.delete(sessionId);
}

export function listSessions(): string[] {
  return Array.from(sessions.keys());
}
