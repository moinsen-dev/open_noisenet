import Cookies from 'js-cookie';

// Cookie names
export const COOKIES = {
  HAS_SEEN_STORY: 'opennoisienet_story_seen',
  SKIP_STORY_PREFERENCE: 'opennoisienet_skip_story',
  CONSENT_PREFERENCES: 'opennoisienet_consent_prefs',
  CONSENT_BANNER_DISMISSED: 'opennoisienet_consent_dismissed',
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

// Cookie consent preferences
export interface CookieConsent {
  essential: boolean;     // Always true - required for site functionality
  analytics: boolean;     // Google Analytics, usage tracking
  functional: boolean;    // Story preferences, theme settings
  marketing: boolean;     // Newsletter tracking, social media
}

export const DEFAULT_CONSENT: CookieConsent = {
  essential: true,       // Always required
  analytics: false,      // Default opt-out
  functional: true,      // Default opt-in for better UX
  marketing: false,      // Default opt-out
};

// Get current consent preferences
export const getConsentPreferences = (): CookieConsent => {
  if (typeof window === 'undefined') return DEFAULT_CONSENT;
  
  const stored = Cookies.get(COOKIES.CONSENT_PREFERENCES);
  if (!stored) return DEFAULT_CONSENT;
  
  try {
    const parsed = JSON.parse(stored);
    return { ...DEFAULT_CONSENT, ...parsed };
  } catch {
    return DEFAULT_CONSENT;
  }
};

// Save consent preferences
export const setConsentPreferences = (preferences: CookieConsent): void => {
  if (typeof window === 'undefined') return;
  
  // Essential cookies are always required
  const safePreferences = { ...preferences, essential: true };
  
  Cookies.set(
    COOKIES.CONSENT_PREFERENCES, 
    JSON.stringify(safePreferences), 
    { ...COOKIE_OPTIONS, expires: 365 } // 1 year for consent
  );
  
  // Mark banner as dismissed
  Cookies.set(COOKIES.CONSENT_BANNER_DISMISSED, 'true', COOKIE_OPTIONS);
  
  // Clean up non-consented cookies
  cleanupNonConsentedCookies(safePreferences);
};

// Check if consent banner should be shown
export const shouldShowConsentBanner = (): boolean => {
  if (typeof window === 'undefined') return false;
  return Cookies.get(COOKIES.CONSENT_BANNER_DISMISSED) !== 'true';
};

// Accept all cookies (convenience function)
export const acceptAllCookies = (): void => {
  setConsentPreferences({
    essential: true,
    analytics: true,
    functional: true,
    marketing: true,
  });
};

// Accept only essential cookies
export const acceptEssentialOnly = (): void => {
  setConsentPreferences(DEFAULT_CONSENT);
};

// Clean up cookies based on consent
const cleanupNonConsentedCookies = (consent: CookieConsent): void => {
  if (typeof window === 'undefined') return;
  
  // If analytics not consented, remove analytics cookies
  if (!consent.analytics) {
    // Remove Google Analytics cookies
    const analyticsCookies = ['_ga', '_ga_*', '_gid', '_gat', '_gtag_*'];
    analyticsCookies.forEach(pattern => {
      if (pattern.includes('*')) {
        // Remove cookies matching pattern
        Object.keys(Cookies.get()).forEach(key => {
          if (key.startsWith(pattern.replace('*', ''))) {
            Cookies.remove(key, { domain: '.' + window.location.hostname });
            Cookies.remove(key);
          }
        });
      } else {
        Cookies.remove(pattern, { domain: '.' + window.location.hostname });
        Cookies.remove(pattern);
      }
    });
  }
  
  // If functional not consented, remove functional cookies (except essential ones)
  if (!consent.functional) {
    // Keep essential functional cookies but remove others
    // Story cookies are considered functional
    if (!consent.essential) {
      clearStoryCookies();
    }
  }
  
  // If marketing not consented, remove marketing cookies
  if (!consent.marketing) {
    // Remove common marketing cookies
    const marketingCookies = ['_fbp', '_fbc', '__utm*', 'hubspotutk'];
    marketingCookies.forEach(pattern => {
      if (pattern.includes('*')) {
        Object.keys(Cookies.get()).forEach(key => {
          if (key.startsWith(pattern.replace('*', ''))) {
            Cookies.remove(key, { domain: '.' + window.location.hostname });
            Cookies.remove(key);
          }
        });
      } else {
        Cookies.remove(pattern, { domain: '.' + window.location.hostname });
        Cookies.remove(pattern);
      }
    });
  }
};

// Helper to check if specific cookie type is consented
export const hasConsentFor = (type: keyof CookieConsent): boolean => {
  const preferences = getConsentPreferences();
  return preferences[type];
};