'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { 
  shouldShowConsentBanner, 
  getConsentPreferences, 
  setConsentPreferences, 
  acceptAllCookies, 
  acceptEssentialOnly,
  type CookieConsent 
} from '@/lib/cookies';
import { Settings, Cookie, Shield, BarChart, Zap, Heart, X, ChevronDown, ChevronUp } from 'lucide-react';

export default function CookieConsentBanner() {
  const [showBanner, setShowBanner] = useState(false);
  const [showSettings, setShowSettings] = useState(false);
  const [preferences, setPreferences] = useState<CookieConsent>(getConsentPreferences());

  useEffect(() => {
    // Only show banner on client side
    setShowBanner(shouldShowConsentBanner());
  }, []);

  const handleAcceptAll = () => {
    acceptAllCookies();
    setShowBanner(false);
  };

  const handleAcceptEssential = () => {
    acceptEssentialOnly();
    setShowBanner(false);
  };

  const handleSavePreferences = () => {
    setConsentPreferences(preferences);
    setShowBanner(false);
    setShowSettings(false);
  };

  const handlePreferenceChange = (key: keyof CookieConsent, value: boolean) => {
    if (key === 'essential') return; // Can't disable essential cookies
    setPreferences(prev => ({ ...prev, [key]: value }));
  };

  if (!showBanner) {
    return null;
  }

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 p-4">
      <Card className="mx-auto max-w-4xl border-slate-200 bg-white/95 backdrop-blur-sm shadow-2xl">
        <CardHeader className="pb-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Cookie className="h-5 w-5 text-slate-600" />
              <CardTitle className="text-lg">Cookie Preferences</CardTitle>
            </div>
            <Button
              variant="ghost"
              size="sm"
              onClick={handleAcceptEssential}
              className="text-slate-400 hover:text-slate-600"
            >
              <X className="h-4 w-4" />
            </Button>
          </div>
        </CardHeader>
        
        <CardContent className="space-y-4">
          {!showSettings ? (
            // Simple banner view
            <div className="space-y-4">
              <CardDescription className="text-sm leading-relaxed">
                We use cookies to enhance your experience, provide analytics insights, and remember your preferences. 
                Your privacy matters - you can customize which cookies we use.{' '}
                <Link href="/privacy" className="text-blue-600 hover:text-blue-700 underline">
                  Learn more in our Privacy Policy
                </Link>
                .
              </CardDescription>
              
              <div className="flex flex-col sm:flex-row gap-2 justify-end">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setShowSettings(true)}
                  className="flex items-center gap-1"
                >
                  <Settings className="h-3 w-3" />
                  Customize
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleAcceptEssential}
                >
                  Essential Only
                </Button>
                <Button
                  size="sm"
                  onClick={handleAcceptAll}
                  className="bg-blue-600 hover:bg-blue-700"
                >
                  Accept All
                </Button>
              </div>
            </div>
          ) : (
            // Detailed settings view
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <CardDescription className="text-sm">
                  Customize your cookie preferences below. Essential cookies are required for the site to function.
                </CardDescription>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setShowSettings(false)}
                  className="flex items-center gap-1 text-slate-500"
                >
                  <ChevronUp className="h-3 w-3" />
                  Simple View
                </Button>
              </div>
              
              <div className="space-y-4">
                {/* Essential Cookies */}
                <div className="flex items-start justify-between p-4 rounded-lg border border-green-200 bg-green-50">
                  <div className="flex items-start gap-3">
                    <Shield className="h-5 w-5 text-green-600 mt-0.5" />
                    <div className="space-y-1">
                      <h4 className="font-medium text-green-900">Essential Cookies</h4>
                      <p className="text-xs text-green-700">
                        Required for basic site functionality, security, and accessibility. Cannot be disabled.
                      </p>
                    </div>
                  </div>
                  <Switch checked={true} disabled />
                </div>
                
                {/* Functional Cookies */}
                <div className="flex items-start justify-between p-4 rounded-lg border border-slate-200">
                  <div className="flex items-start gap-3">
                    <Zap className="h-5 w-5 text-blue-600 mt-0.5" />
                    <div className="space-y-1">
                      <h4 className="font-medium text-slate-900">Functional Cookies</h4>
                      <p className="text-xs text-slate-600">
                        Remember your preferences like story settings and theme choices for a better experience.
                      </p>
                    </div>
                  </div>
                  <Switch 
                    checked={preferences.functional}
                    onCheckedChange={(value) => handlePreferenceChange('functional', value)}
                  />
                </div>
                
                {/* Analytics Cookies */}
                <div className="flex items-start justify-between p-4 rounded-lg border border-slate-200">
                  <div className="flex items-start gap-3">
                    <BarChart className="h-5 w-5 text-purple-600 mt-0.5" />
                    <div className="space-y-1">
                      <h4 className="font-medium text-slate-900">Analytics Cookies</h4>
                      <p className="text-xs text-slate-600">
                        Help us understand how visitors use our site to improve performance and user experience.
                      </p>
                    </div>
                  </div>
                  <Switch 
                    checked={preferences.analytics}
                    onCheckedChange={(value) => handlePreferenceChange('analytics', value)}
                  />
                </div>
                
                {/* Marketing Cookies */}
                <div className="flex items-start justify-between p-4 rounded-lg border border-slate-200">
                  <div className="flex items-start gap-3">
                    <Heart className="h-5 w-5 text-rose-600 mt-0.5" />
                    <div className="space-y-1">
                      <h4 className="font-medium text-slate-900">Marketing Cookies</h4>
                      <p className="text-xs text-slate-600">
                        Track newsletter signups and social media interactions to measure campaign effectiveness.
                      </p>
                    </div>
                  </div>
                  <Switch 
                    checked={preferences.marketing}
                    onCheckedChange={(value) => handlePreferenceChange('marketing', value)}
                  />
                </div>
              </div>
              
              <div className="flex justify-end gap-2 pt-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleAcceptEssential}
                >
                  Essential Only
                </Button>
                <Button
                  size="sm"
                  onClick={handleSavePreferences}
                  className="bg-blue-600 hover:bg-blue-700"
                >
                  Save Preferences
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}