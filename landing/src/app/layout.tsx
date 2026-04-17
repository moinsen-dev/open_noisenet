import type { Metadata } from 'next';
import './globals.css';
import CookieConsentBanner from '@/components/cookie-consent-banner';
import Analytics from '@/components/analytics';

export const metadata: Metadata = {
  title: 'OpenNoiseNet - Public + Pro Noise Monitoring',
  description: 'OpenNoiseNet is a privacy-first Hybrid Public + Pro noise monitoring platform with smartphone field nodes, public map visibility, and operator evidence workflows for episodes, cases, and exports.',
  keywords: 'noise monitoring, public map, smartphone field node, privacy-first, property operations, housing, episodes, case export, open source',
  authors: [{ name: 'OpenNoiseNet Community' }],
  openGraph: {
    title: 'OpenNoiseNet - Public + Pro Noise Monitoring',
    description: 'Privacy-first noise monitoring with smartphone field nodes, public visibility, and operator evidence workflows.',
    url: 'https://opennoienet.org',
    siteName: 'OpenNoiseNet',
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'OpenNoiseNet - Public + Pro Noise Monitoring',
    description: 'Public map visibility, smartphone field nodes, and operator evidence workflows.',
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  verification: {
    google: process.env.GOOGLE_SITE_VERIFICATION,
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body className="font-sans antialiased">
        {children}
        <CookieConsentBanner />
        <Analytics />
      </body>
    </html>
  );
}
