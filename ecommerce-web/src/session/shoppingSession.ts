const STORAGE_KEY = "freshmart.shoppingSession";

const ADJECTIVES = [
  "brisk",
  "sunny",
  "calm",
  "bold",
  "merry",
  "swift",
  "lucky",
  "cozy",
] as const;

const NOUNS = [
  "otter",
  "fox",
  "sparrow",
  "maple",
  "river",
  "meadow",
  "harbor",
  "willow",
] as const;

export type ShoppingSession = {
  sessionId: string;
  username: string;
};

type StoredSession = ShoppingSession & {
  status: "active";
};

let currentSession: StoredSession | null = loadFromStorage();

function loadFromStorage(): StoredSession | null {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as StoredSession;
    if (
      parsed?.status === "active" &&
      typeof parsed.sessionId === "string" &&
      parsed.sessionId.length > 0 &&
      typeof parsed.username === "string" &&
      parsed.username.length > 0
    ) {
      return parsed;
    }
  } catch {
    // Ignore corrupt storage and start fresh on next ensure/start.
  }
  return null;
}

function persist(session: StoredSession | null): void {
  currentSession = session;
  if (session) {
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify(session));
  } else {
    sessionStorage.removeItem(STORAGE_KEY);
  }
}

function pickRandom<T extends readonly string[]>(items: T): T[number] {
  return items[Math.floor(Math.random() * items.length)];
}

function randomSuffix(): string {
  return String(Math.floor(1000 + Math.random() * 9000));
}

function generateUsername(): string {
  return `${pickRandom(ADJECTIVES)}_${pickRandom(NOUNS)}_${randomSuffix()}`;
}

/** UUID v4; works on plain HTTP where crypto.randomUUID is unavailable (non-secure context). */
function generateSessionId(): string {
  if (typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function createSession(): StoredSession {
  return {
    sessionId: generateSessionId(),
    username: generateUsername(),
    status: "active",
  };
}

/** Starts a new shopping session with independent session id and username. */
export function startSession(): ShoppingSession {
  const session = createSession();
  persist(session);
  return { sessionId: session.sessionId, username: session.username };
}

export function getSession(): ShoppingSession | null {
  if (!currentSession) return null;
  return {
    sessionId: currentSession.sessionId,
    username: currentSession.username,
  };
}

export function getSessionId(): string | null {
  return currentSession?.sessionId ?? null;
}

export function getUsername(): string | null {
  return currentSession?.username ?? null;
}

/** Clears the active shopping session after successful payment. */
export function endSession(): void {
  persist(null);
}

/** Reuses the stored session or creates one for edge routes (e.g. direct /cart). */
export function ensureSession(): ShoppingSession {
  if (currentSession) {
    return {
      sessionId: currentSession.sessionId,
      username: currentSession.username,
    };
  }
  return startSession();
}
