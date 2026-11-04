// @vitest-environment jsdom
import { beforeEach, describe, expect, it } from 'vitest';
import Cookies from 'js-cookie';
import {
  COOKIES, acceptEssentialOnly, getConsentPreferences, markStoryAsSeen,
  setConsentPreferences, setSkipStoryPreference, shouldShowStoryFirst,
} from './cookies';

describe('optional cookie consent', () => {
  beforeEach(() => {
    for (const name of Object.values(COOKIES)) Cookies.remove(name);
  });

  it('does not create story cookies or redirect before consent', () => {
    markStoryAsSeen();
    setSkipStoryPreference(true);
    expect(Cookies.get(COOKIES.HAS_SEEN_STORY)).toBeUndefined();
    expect(Cookies.get(COOKIES.SKIP_STORY_PREFERENCE)).toBeUndefined();
    expect(shouldShowStoryFirst()).toBe(false);
  });

  it('essential-only removes optional story cookies and does not recreate them', () => {
    setConsentPreferences({ essential: true, functional: true, analytics: false, marketing: false });
    setSkipStoryPreference(true);
    expect(Cookies.get(COOKIES.SKIP_STORY_PREFERENCE)).toBe('true');
    acceptEssentialOnly();
    expect(getConsentPreferences()).toEqual({ essential: true, functional: false, analytics: false, marketing: false });
    expect(Cookies.get(COOKIES.SKIP_STORY_PREFERENCE)).toBeUndefined();
    expect(Cookies.get(COOKIES.HAS_SEEN_STORY)).toBeUndefined();
    markStoryAsSeen();
    expect(Cookies.get(COOKIES.HAS_SEEN_STORY)).toBeUndefined();
  });

  it('permits story preference cookies only after functional consent', () => {
    setConsentPreferences({ essential: true, functional: true, analytics: false, marketing: false });
    expect(shouldShowStoryFirst()).toBe(true);
    markStoryAsSeen();
    expect(Cookies.get(COOKIES.HAS_SEEN_STORY)).toBe('true');
    expect(shouldShowStoryFirst()).toBe(false);
  });
});
