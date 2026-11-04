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
    // Cookies are unavailable during static rendering; hydrate after mounting.
    // eslint-disable-next-line react-hooks/set-state-in-effect
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
    <div className="onn-consent fixed bottom-0 left-0 right-0 z-50 p-4 max-h-[85vh] overflow-y-auto">
      <Card className="mx-auto max-w-4xl border-slate-200 bg-white/95 backdrop-blur-sm shadow-2xl">
        <CardHeader className="pb-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Cookie className="h-5 w-5 text-slate-600" />
              <CardTitle className="text-lg text-slate-900">Cookie-Einstellungen</CardTitle>
            </div>
            <Button
              variant="ghost"
              size="sm"
              onClick={handleAcceptEssential}
              aria-label="Schließen und nur notwendige Cookies verwenden"
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
                Wir speichern deine Cookie-Auswahl. Optionale Funktionen und gegebenenfalls eingerichtete Analysen benötigen deine Zustimmung.
                Du kannst nur notwendige Cookies erlauben.{' '}
                <Link href="/privacy" className="text-blue-600 hover:text-blue-700 underline">
                  Mehr zum Datenschutz (EN)
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
                  Einstellungen
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleAcceptEssential}
                >
                  Nur notwendige
                </Button>
                <Button
                  size="sm"
                  onClick={handleAcceptAll}
                  className="bg-blue-600 hover:bg-blue-700"
                >
                  Alle erlauben
                </Button>
              </div>
            </div>
          ) : (
            // Detailed settings view
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <CardDescription className="text-sm">
                  Wähle die erlaubten Kategorien. Die Speicherung deiner Auswahl bleibt notwendig.
                </CardDescription>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setShowSettings(false)}
                  className="flex items-center gap-1 text-slate-500"
                >
                  <ChevronUp className="h-3 w-3" />
                  Zurück
                </Button>
              </div>

              <div className="space-y-4">
                {/* Notwendige Cookies */}
                <div className="flex items-start justify-between p-4 rounded-lg border border-green-200 bg-green-50">
                  <div className="flex items-start gap-3">
                    <Shield className="h-5 w-5 text-green-600 mt-0.5" />
                    <div className="space-y-1">
                      <h4 className="font-medium text-green-900">Notwendige Cookies</h4>
                      <p className="text-xs text-green-700">
                        Speichern deine Cookie-Auswahl. Diese Funktion bleibt aktiv.
                      </p>
                    </div>
                  </div>
                  <Switch aria-label="Notwendige Cookies" checked={true} disabled />
                </div>

                {/* Funktionale Cookies */}
                <div className="flex items-start justify-between p-4 rounded-lg border border-slate-200">
                  <div className="flex items-start gap-3">
                    <Zap className="h-5 w-5 text-blue-600 mt-0.5" />
                    <div className="space-y-1">
                      <h4 className="font-medium text-slate-900">Funktionale Cookies</h4>
                      <p className="text-xs text-slate-600">
                        Optionale Anzeigeeinstellungen. Derzeit sind keine zusätzlichen Funktionen eingerichtet.
                      </p>
                    </div>
                  </div>
                  <Switch
                    aria-label="Funktionale Cookies"
                    checked={preferences.functional}
                    onCheckedChange={(value) => handlePreferenceChange('functional', value)}
                  />
                </div>

                {/* Analyse-Cookies */}
                <div className="flex items-start justify-between p-4 rounded-lg border border-slate-200">
                  <div className="flex items-start gap-3">
                    <BarChart className="h-5 w-5 text-purple-600 mt-0.5" />
                    <div className="space-y-1">
                      <h4 className="font-medium text-slate-900">Analyse-Cookies</h4>
                      <p className="text-xs text-slate-600">
                        Optionale Nutzungsanalyse, sofern vom Betreiber eingerichtet.
                      </p>
                    </div>
                  </div>
                  <Switch
                    aria-label="Analyse-Cookies"
                    checked={preferences.analytics}
                    onCheckedChange={(value) => handlePreferenceChange('analytics', value)}
                  />
                </div>

                {/* Marketing-Cookies */}
                <div className="flex items-start justify-between p-4 rounded-lg border border-slate-200">
                  <div className="flex items-start gap-3">
                    <Heart className="h-5 w-5 text-rose-600 mt-0.5" />
                    <div className="space-y-1">
                      <h4 className="font-medium text-slate-900">Marketing-Cookies</h4>
                      <p className="text-xs text-slate-600">
                        Derzeit sind keine Marketing-Dienste eingerichtet.
                      </p>
                    </div>
                  </div>
                  <Switch
                    aria-label="Marketing-Cookies"
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
                  Nur notwendige
                </Button>
                <Button
                  size="sm"
                  onClick={handleSavePreferences}
                  className="bg-blue-600 hover:bg-blue-700"
                >
                  Auswahl speichern
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
