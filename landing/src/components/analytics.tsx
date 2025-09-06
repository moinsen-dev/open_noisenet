'use client';

import { useEffect } from 'react';
import { hasConsentFor } from '@/lib/cookies';

declare global {
  interface Window {
    gtag?: (...args: any[]) => void;
    dataLayer?: any[];
  }
}

const GA_TRACKING_ID = process.env.NEXT_PUBLIC_GA_TRACKING_ID;

// Initialize Google Analytics
const initGA = () => {
  if (!GA_TRACKING_ID) return;

  // Create script tag for gtag
  const script = document.createElement('script');
  script.async = true;
  script.src = `https://www.googletagmanager.com/gtag/js?id=${GA_TRACKING_ID}`;
  document.head.appendChild(script);

  // Initialize dataLayer and gtag
  window.dataLayer = window.dataLayer || [];
  window.gtag = function (...args: any[]) {
    window.dataLayer!.push(args);
  };

  // Configure Google Analytics
  window.gtag!('js', new Date());
  window.gtag!('config', GA_TRACKING_ID, {
    // Privacy-friendly configuration
    anonymize_ip: true,           // Anonymize IP addresses
    allow_google_signals: false,  // Disable Google Signals (cross-device tracking)
    allow_ad_personalization_signals: false, // Disable ad personalization
    cookie_expires: 60 * 60 * 24 * 7, // Cookies expire after 1 week (not 2 years)
    send_page_view: true,
  });

  console.log('Google Analytics initialized with privacy-friendly settings');
};

// Remove Google Analytics
const removeGA = () => {
  // Remove scripts
  const scripts = document.querySelectorAll('script[src*="googletagmanager.com"]');
  scripts.forEach(script => script.remove());
  
  // Clear dataLayer
  if (window.dataLayer) {
    window.dataLayer = [];
  }
  
  // Remove gtag function
  if (window.gtag) {
    delete (window as any).gtag;
  }

  // Clear Google Analytics cookies
  const gaCookies = ['_ga', '_ga_*', '_gid', '_gat', '_gtag_*'];
  gaCookies.forEach(pattern => {
    if (pattern.includes('*')) {
      // Remove cookies matching pattern
      Object.keys(document.cookie.split(';').reduce((cookies, cookie) => {
        const [name] = cookie.split('=');
        return { ...cookies, [name.trim()]: true };
      }, {})).forEach(name => {
        if (name.startsWith(pattern.replace('*', ''))) {
          document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/; domain=${window.location.hostname}`;
          document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/; domain=.${window.location.hostname}`;
        }
      });
    } else {
      document.cookie = `${pattern}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/; domain=${window.location.hostname}`;
      document.cookie = `${pattern}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/; domain=.${window.location.hostname}`;
    }
  });

  console.log('Google Analytics removed and cookies cleared');
};

// Track page view
export const trackPageView = (path: string) => {
  if (!hasConsentFor('analytics') || !window.gtag) return;
  
  window.gtag!('config', GA_TRACKING_ID, {
    page_path: path,
  });
};

// Track custom event
export const trackEvent = (action: string, category: string, label?: string, value?: number) => {
  if (!hasConsentFor('analytics') || !window.gtag) return;
  
  window.gtag!('event', action, {
    event_category: category,
    event_label: label,
    value: value,
  });
};

// Analytics component that manages consent-based loading
export default function Analytics() {
  useEffect(() => {
    const checkAndUpdateAnalytics = () => {
      const hasAnalyticsConsent = hasConsentFor('analytics');
      const gaExists = !!window.gtag;
      
      if (hasAnalyticsConsent && !gaExists) {
        // User consented and GA is not loaded - initialize it
        initGA();
      } else if (!hasAnalyticsConsent && gaExists) {
        // User revoked consent and GA is loaded - remove it
        removeGA();
      }
    };

    // Check on mount
    checkAndUpdateAnalytics();
    
    // Listen for consent changes (via storage events)
    const handleStorageChange = (e: StorageEvent) => {
      if (e.key === 'opennoisienet_consent_prefs') {
        checkAndUpdateAnalytics();
      }
    };

    window.addEventListener('storage', handleStorageChange);
    
    // Also check periodically in case cookies change
    const interval = setInterval(checkAndUpdateAnalytics, 5000);
    
    return () => {
      window.removeEventListener('storage', handleStorageChange);
      clearInterval(interval);
    };
  }, []);

  return null; // This component doesn't render anything
}