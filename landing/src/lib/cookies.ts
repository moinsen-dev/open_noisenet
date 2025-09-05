import Cookies from 'js-cookie';

// Cookie names
export const COOKIES = {
  HAS_SEEN_STORY: 'opennoisienet_story_seen',
  SKIP_STORY_PREFERENCE: 'opennoisienet_skip_story',
} as const;

// Cookie configuration
export const COOKIE_OPTIONS = {
  expires: 30, // 30 days
  sameSite: 'lax' as const,
  secure: process.env.NODE_ENV === 'production',
};

// First visit detection
export const hasSeenStory = (): boolean => {
  if (typeof window === 'undefined') return true; // SSR fallback
  return Cookies.get(COOKIES.HAS_SEEN_STORY) === 'true';
};

export const markStoryAsSeen = (): void => {
  if (typeof window === 'undefined') return;
  Cookies.set(COOKIES.HAS_SEEN_STORY, 'true', COOKIE_OPTIONS);
};

// Story skip preference
export const hasSkipStoryPreference = (): boolean => {
  if (typeof window === 'undefined') return false;
  return Cookies.get(COOKIES.SKIP_STORY_PREFERENCE) === 'true';
};

export const setSkipStoryPreference = (skip: boolean): void => {
  if (typeof window === 'undefined') return;
  if (skip) {
    Cookies.set(COOKIES.SKIP_STORY_PREFERENCE, 'true', COOKIE_OPTIONS);
    markStoryAsSeen(); // Also mark story as seen if skipped
  } else {
    Cookies.remove(COOKIES.SKIP_STORY_PREFERENCE);
  }
};

// Clear all story-related cookies (for testing/reset)
export const clearStoryCookies = (): void => {
  if (typeof window === 'undefined') return;
  Cookies.remove(COOKIES.HAS_SEEN_STORY);
  Cookies.remove(COOKIES.SKIP_STORY_PREFERENCE);
};

// Check if this is a first-time visitor who should see the story
export const shouldShowStoryFirst = (): boolean => {
  if (typeof window === 'undefined') return false;
  return !hasSeenStory() && !hasSkipStoryPreference();
};