'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { 
  getConsentPreferences, 
  setConsentPreferences, 
  acceptAllCookies, 
  acceptEssentialOnly,
  type CookieConsent 
} from '@/lib/cookies';
import { ArrowLeft, Cookie, Shield, BarChart, Zap, Heart, CheckCircle, Info, Trash2 } from 'lucide-react';

export default function CookiePreferencesPage() {
  const [preferences, setPreferences] = useState<CookieConsent>(getConsentPreferences());
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    // Load current preferences on client side
    setPreferences(getConsentPreferences());
  }, []);

  const handlePreferenceChange = (key: keyof CookieConsent, value: boolean) => {
    if (key === 'essential') return; // Can't disable essential cookies
    setPreferences(prev => ({ ...prev, [key]: value }));
    setSaved(false);
  };

  const handleSavePreferences = () => {
    setConsentPreferences(preferences);
    setSaved(true);
    setTimeout(() => setSaved(false), 3000); // Hide saved message after 3 seconds
  };

  const handleAcceptAll = () => {
    acceptAllCookies();
    setPreferences({
      essential: true,
      analytics: true,
      functional: true,
      marketing: true,
    });
    setSaved(true);
    setTimeout(() => setSaved(false), 3000);
  };

  const handleAcceptEssential = () => {
    acceptEssentialOnly();
    setPreferences(getConsentPreferences());
    setSaved(true);
    setTimeout(() => setSaved(false), 3000);
  };

  const handleClearAllCookies = () => {
    // This would require more careful implementation in a real app
    if (confirm('This will clear all cookies and reload the page. Continue?')) {
      // Clear all cookies except essential ones
      document.cookie.split(";").forEach(function(c) { 
        document.cookie = c.replace(/^ +/, "").replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/"); 
      });
      window.location.reload();
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 via-white to-slate-100">
      <div className="container mx-auto px-4 py-8 max-w-4xl">
        {/* Header */}
        <div className="mb-8">
          <Link 
            href="/" 
            className="inline-flex items-center gap-2 text-slate-600 hover:text-slate-800 mb-4"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to OpenNoiseNet
          </Link>
          
          <div className="flex items-center gap-3 mb-2">
            <Cookie className="h-8 w-8 text-slate-700" />
            <h1 className="text-3xl font-bold text-slate-900">Cookie Preferences</h1>
          </div>
          
          <p className="text-slate-600 leading-relaxed">
            Manage your cookie preferences and control what data we collect. 
            Your choices help us respect your privacy while providing the best possible experience.
          </p>
        </div>

        {/* Success Message */}
        {saved && (
          <Card className="mb-6 border-green-200 bg-green-50">
            <CardContent className="p-4">
              <div className="flex items-center gap-2 text-green-800">
                <CheckCircle className="h-5 w-5" />
                <span className="font-medium">Preferences saved successfully!</span>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Cookie Categories */}
        <div className="space-y-6">
          {/* Essential Cookies */}
          <Card className="border-green-200 bg-green-50/50">
            <CardHeader>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <Shield className="h-6 w-6 text-green-600" />
                  <div>
                    <CardTitle className="text-green-900">Essential Cookies</CardTitle>
                    <CardDescription className="text-green-700">
                      Always active - Required for the website to function properly
                    </CardDescription>
                  </div>
                </div>
                <Switch checked={true} disabled />
              </div>
            </CardHeader>
            <CardContent>
              <div className="space-y-3 text-sm text-green-800">
                <div className="flex items-start gap-2">
                  <Info className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <div>
                    <strong>Security:</strong> CSRF protection, session management, and secure form submissions
                  </div>
                </div>
                <div className="flex items-start gap-2">
                  <Info className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <div>
                    <strong>Functionality:</strong> Site navigation, accessibility preferences, and error prevention
                  </div>
                </div>
                <div className="flex items-start gap-2">
                  <Info className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <div>
                    <strong>Legal:</strong> Cookie consent preferences (this choice itself requires a cookie!)
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Functional Cookies */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <Zap className="h-6 w-6 text-blue-600" />
                  <div>
                    <CardTitle className="text-slate-900">Functional Cookies</CardTitle>
                    <CardDescription>
                      Enhanced features and personalized experience
                    </CardDescription>
                  </div>
                </div>
                <Switch 
                  checked={preferences.functional}
                  onCheckedChange={(value) => handlePreferenceChange('functional', value)}
                />
              </div>
            </CardHeader>
            <CardContent>
              <div className="space-y-3 text-sm text-slate-700">
                <div className="flex items-start gap-2">
                  <Info className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <div>
                    <strong>Story Preferences:</strong> Remember if you&apos;ve seen the interactive story and your viewing preferences
                  </div>
                </div>
                <div className="flex items-start gap-2">
                  <Info className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <div>
                    <strong>UI Settings:</strong> Theme preferences, language settings, and accessibility options
                  </div>
                </div>
                <div className="flex items-start gap-2">
                  <Info className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <div>
                    <strong>Forms:</strong> Remember form inputs to prevent data loss during navigation
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Analytics Cookies */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <BarChart className="h-6 w-6 text-purple-600" />
                  <div>
                    <CardTitle className="text-slate-900">Analytics Cookies</CardTitle>
                    <CardDescription>
                      Help us understand how visitors use our site
                    </CardDescription>
                  </div>
                </div>
                <Switch 
                  checked={preferences.analytics}
                  onCheckedChange={(value) => handlePreferenceChange('analytics', value)}
                />
              </div>
            </CardHeader>
            <CardContent>
              <div className="space-y-3 text-sm text-slate-700">
                <div className="flex items-start gap-2">
                  <Info className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <div>
                    <strong>Usage Analytics:</strong> Page views, session duration, and popular content (via Google Analytics)
                  </div>
                </div>
                <div className="flex items-start gap-2">
                  <Info className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <div>
                    <strong>Performance:</strong> Load times, error tracking, and technical performance metrics
                  </div>
                </div>
                <div className="flex items-start gap-2">
                  <Info className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <div>
                    <strong>Privacy:</strong> All data is anonymized and aggregated - we never track individual users
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Marketing Cookies */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <Heart className="h-6 w-6 text-rose-600" />
                  <div>
                    <CardTitle className="text-slate-900">Marketing Cookies</CardTitle>
                    <CardDescription>
                      Measure campaign effectiveness and social engagement
                    </CardDescription>
                  </div>
                </div>
                <Switch 
                  checked={preferences.marketing}
                  onCheckedChange={(value) => handlePreferenceChange('marketing', value)}
                />
              </div>
            </CardHeader>
            <CardContent>
              <div className="space-y-3 text-sm text-slate-700">
                <div className="flex items-start gap-2">
                  <Info className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <div>
                    <strong>Newsletter:</strong> Track newsletter signups and email campaign effectiveness
                  </div>
                </div>
                <div className="flex items-start gap-2">
                  <Info className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <div>
                    <strong>Social Media:</strong> Measure social media referrals and sharing activity
                  </div>
                </div>
                <div className="flex items-start gap-2">
                  <Info className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <div>
                    <strong>Community Growth:</strong> Understand how people discover and engage with OpenNoiseNet
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Action Buttons */}
        <div className="mt-8 space-y-4">
          <div className="flex flex-col sm:flex-row gap-3">
            <Button
              onClick={handleSavePreferences}
              className="flex-1 bg-blue-600 hover:bg-blue-700"
            >
              Save Preferences
            </Button>
            <Button
              variant="outline"
              onClick={handleAcceptAll}
              className="flex-1"
            >
              Accept All Cookies
            </Button>
            <Button
              variant="outline"
              onClick={handleAcceptEssential}
              className="flex-1"
            >
              Essential Only
            </Button>
          </div>
          
          <div className="flex justify-center">
            <Button
              variant="ghost"
              size="sm"
              onClick={handleClearAllCookies}
              className="text-slate-500 hover:text-slate-700 flex items-center gap-1"
            >
              <Trash2 className="h-3 w-3" />
              Clear All Cookies
            </Button>
          </div>
        </div>

        {/* Legal Links */}
        <div className="mt-8 pt-6 border-t border-slate-200 text-center text-sm text-slate-600">
          <p>
            For more information, read our{' '}
            <Link href="/privacy" className="text-blue-600 hover:text-blue-700 underline">
              Privacy Policy
            </Link>
            {' '}and{' '}
            <Link href="/terms" className="text-blue-600 hover:text-blue-700 underline">
              Terms of Service
            </Link>
            .
          </p>
        </div>
      </div>
    </div>
  );
}