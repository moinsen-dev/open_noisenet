'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { getAssetPath } from '@/lib/asset-path';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import NoiseVisualization from '@/components/noise-visualization';
import { shouldShowStoryFirst } from '@/lib/cookies';
import { 
  Github, 
  Download, 
  Smartphone, 
  Users, 
  BarChart3, 
  Shield,
  Globe,
  Zap,
  Heart,
  Mail,
  MapPin,
  Headphones,
  Volume2,
  Building,
  Truck
} from 'lucide-react';

export default function Home() {
  const router = useRouter();

  useEffect(() => {
    // Check if this is a first-time visitor who should see the story
    if (shouldShowStoryFirst()) {
      router.push('/story');
    }
  }, [router]);

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950">
      {/* Navigation */}
      <nav className="fixed top-0 left-0 right-0 z-50 bg-slate-950/80 backdrop-blur-md border-b border-slate-800">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center space-x-2">
              <NoiseVisualization />
              <span className="text-xl font-bold text-white">OpenNoiseNet</span>
            </div>
            <div className="hidden md:flex items-center space-x-6">
              <Link href="/story" className="text-slate-300 hover:text-white transition-colors">
                Our Story
              </Link>
              <Link href="/technology" className="text-slate-300 hover:text-white transition-colors">
                Technology
              </Link>
              <Link href="#features" className="text-slate-300 hover:text-white transition-colors">
                Features
              </Link>
              <Link href="#download" className="text-slate-300 hover:text-white transition-colors">
                Apps
              </Link>
              <Link href="#contribute" className="text-slate-300 hover:text-white transition-colors">
                Contribute
              </Link>
              <Link href="#newsletter" className="text-slate-300 hover:text-white transition-colors">
                Newsletter
              </Link>
            </div>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="pt-32 pb-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
            <div className="space-y-8">
              <div className="space-y-4">
                <h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold text-white leading-tight">
                  Democratizing 
                  <span className="text-warn-400 block">Environmental</span>
                  <span className="text-noise-400">Noise Monitoring</span>
                </h1>
                <p className="text-xl text-slate-300 leading-relaxed">
                  Join the global network of citizen-operated noise sensors. Build affordable DIY devices, 
                  contribute data, and help create quieter communities through open-source environmental monitoring.
                </p>
              </div>
              
              <div className="flex flex-col sm:flex-row gap-4">
                <Button 
                  variant="noise" 
                  size="lg" 
                  className="text-lg px-8 py-6 h-auto"
                  asChild
                >
                  <Link href="#download">
                    <Download className="w-5 h-5" />
                    Get the Apps
                  </Link>
                </Button>
                
                <Button 
                  variant="outline" 
                  size="lg" 
                  className="text-lg px-8 py-6 h-auto border-slate-600 hover:bg-slate-800"
                  asChild
                >
                  <Link href="https://github.com/moinsen-dev/open_noisenet" target="_blank">
                    <Github className="w-5 h-5" />
                    View on GitHub
                  </Link>
                </Button>
              </div>

              <div className="flex items-center space-x-6 text-sm text-slate-400">
                <div className="flex items-center space-x-2">
                  <Users className="w-4 h-4" />
                  <span>Community Driven</span>
                </div>
                <div className="flex items-center space-x-2">
                  <Shield className="w-4 h-4" />
                  <span>Privacy First</span>
                </div>
                <div className="flex items-center space-x-2">
                  <Globe className="w-4 h-4" />
                  <span>Open Source</span>
                </div>
              </div>
            </div>

            <div className="relative">
              <div className="relative bg-gradient-to-br from-slate-800 to-slate-900 rounded-2xl p-8 shadow-2xl">
                {/* Phone mockup representing the app */}
                <div className="bg-slate-950 rounded-2xl p-4 mx-auto max-w-sm">
                  <div className="bg-gradient-to-br from-noise-900 to-slate-900 rounded-xl p-6 space-y-6">
                    <div className="flex items-center justify-between">
                      <Volume2 className="w-6 h-6 text-warn-400" />
                      <div className="text-right">
                        <div className="text-2xl font-bold text-white">52 dB</div>
                        <div className="text-xs text-slate-400">Current Level</div>
                      </div>
                    </div>
                    
                    <div className="space-y-2">
                      <div className="flex justify-between items-center text-sm">
                        <span className="text-slate-300">15-min Avg</span>
                        <span className="text-warn-400 font-medium">48 dB</span>
                      </div>
                      <div className="w-full bg-slate-800 rounded-full h-2">
                        <div className="bg-gradient-to-r from-warn-500 to-warn-400 h-2 rounded-full" style={{width: '65%'}}></div>
                      </div>
                    </div>

                    <NoiseVisualization />

                    <div className="grid grid-cols-3 gap-3 text-center text-xs">
                      <div className="bg-slate-800 rounded-lg p-2">
                        <Building className="w-4 h-4 mx-auto mb-1 text-slate-400" />
                        <div className="text-white">Urban</div>
                      </div>
                      <div className="bg-slate-800 rounded-lg p-2">
                        <Truck className="w-4 h-4 mx-auto mb-1 text-slate-400" />
                        <div className="text-white">Traffic</div>
                      </div>
                      <div className="bg-slate-800 rounded-lg p-2">
                        <MapPin className="w-4 h-4 mx-auto mb-1 text-slate-400" />
                        <div className="text-white">Active</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              
              {/* Floating elements */}
              <div className="absolute -top-4 -left-4 bg-warn-500 p-3 rounded-full shadow-lg noise-pulse">
                <Headphones className="w-6 h-6 text-white" />
              </div>
              
              <div className="absolute -bottom-4 -right-4 bg-noise-500 p-3 rounded-full shadow-lg noise-pulse">
                <BarChart3 className="w-6 h-6 text-white" />
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Problem Statement Section */}
      <section className="py-20 px-4 sm:px-6 lg:px-8 bg-slate-900/50">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl sm:text-4xl font-bold text-white mb-6">
              Noise Pollution Is Everywhere
            </h2>
            <p className="text-xl text-slate-300 max-w-3xl mx-auto">
              Millions suffer from noise-related health issues, sleep disruption, and reduced quality of life. 
              Traditional monitoring is expensive and limited to specific locations.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 items-center">
            <div className="space-y-6">
              <div className="bg-slate-800/50 rounded-xl p-6 border border-slate-700">
                <div className="flex items-center space-x-3 mb-4">
                  <div className="bg-red-500 p-2 rounded-lg">
                    <Building className="w-6 h-6 text-white" />
                  </div>
                  <h3 className="text-xl font-semibold text-white">Urban Noise Crisis</h3>
                </div>
                <p className="text-slate-300">
                  Studies show that 65% of city residents are exposed to noise levels exceeding WHO recommendations, 
                  leading to stress, cardiovascular issues, and sleep disorders.
                </p>
              </div>

              <div className="bg-slate-800/50 rounded-xl p-6 border border-slate-700">
                <div className="flex items-center space-x-3 mb-4">
                  <div className="bg-orange-500 p-2 rounded-lg">
                    <Truck className="w-6 h-6 text-white" />
                  </div>
                  <h3 className="text-xl font-semibold text-white">Limited Monitoring</h3>
                </div>
                <p className="text-slate-300">
                  Professional noise monitoring equipment costs thousands of euros and provides limited geographic coverage, 
                  leaving communities without adequate data for advocacy.
                </p>
              </div>
            </div>

            <div className="relative">
              {/* Using onn-2.png concept - person affected by noise at night */}
              <div className="bg-gradient-to-br from-slate-800 to-slate-900 rounded-2xl p-8 shadow-2xl">
                <div className="aspect-square bg-gradient-to-br from-slate-700 to-slate-800 rounded-xl flex items-center justify-center">
                  <div className="text-center space-y-4 p-6">
                    <div className="bg-red-500/20 p-6 rounded-full mx-auto w-fit">
                      <Volume2 className="w-12 h-12 text-red-400" />
                    </div>
                    <div className="space-y-2">
                      <div className="text-3xl font-bold text-red-400">80+ dB</div>
                      <div className="text-sm text-slate-300">Average city noise</div>
                      <div className="text-xs text-slate-400">WHO recommends ≤55 dB</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Solution Section */}
      <section id="features" className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl sm:text-4xl font-bold text-white mb-6">
              Our Solution: Community-Powered Monitoring
            </h2>
            <p className="text-xl text-slate-300 max-w-3xl mx-auto">
              OpenNoiseNet democratizes environmental monitoring through affordable DIY hardware, 
              open-source software, and privacy-first community data sharing.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <Card className="bg-slate-800/50 border-slate-700 hover:bg-slate-800/70 transition-colors">
              <CardHeader>
                <div className="bg-warn-500 p-3 rounded-lg w-fit">
                  <Zap className="w-6 h-6 text-white" />
                </div>
                <CardTitle className="text-white">Affordable Hardware</CardTitle>
              </CardHeader>
              <CardContent>
                <CardDescription className="text-slate-300">
                  Build your own noise sensor with ESP32 and MEMS microphones for just €30-45. 
                  Complete DIY guide and 3D-printable enclosures included.
                </CardDescription>
              </CardContent>
            </Card>

            <Card className="bg-slate-800/50 border-slate-700 hover:bg-slate-800/70 transition-colors">
              <CardHeader>
                <div className="bg-noise-500 p-3 rounded-lg w-fit">
                  <Globe className="w-6 h-6 text-white" />
                </div>
                <CardTitle className="text-white">Open Data Network</CardTitle>
              </CardHeader>
              <CardContent>
                <CardDescription className="text-slate-300">
                  Join a global network of community sensors. All data is open, anonymized, 
                  and available for research, advocacy, and policy-making.
                </CardDescription>
              </CardContent>
            </Card>

            <Card className="bg-slate-800/50 border-slate-700 hover:bg-slate-800/70 transition-colors">
              <CardHeader>
                <div className="bg-green-500 p-3 rounded-lg w-fit">
                  <Shield className="w-6 h-6 text-white" />
                </div>
                <CardTitle className="text-white">Privacy by Design</CardTitle>
              </CardHeader>
              <CardContent>
                <CardDescription className="text-slate-300">
                  Default operation stores only numeric sound levels. Optional encrypted audio snippets 
                  for ML analysis are deleted after 7 days. GDPR compliant.
                </CardDescription>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* Download Section */}
      <section id="download" className="py-20 px-4 sm:px-6 lg:px-8 bg-slate-900/50">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-3xl sm:text-4xl font-bold text-white mb-6">
            Get Started Today
          </h2>
          <p className="text-xl text-slate-300 mb-12">
            Download our mobile apps to monitor noise in your area or view community data from around the world.
          </p>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-8 max-w-2xl mx-auto">
            <Button 
              variant="outline" 
              size="lg" 
              className="h-auto py-6 px-8 border-slate-600 hover:bg-slate-800 group"
              asChild
            >
              <Link href="#" className="flex flex-col items-center space-y-2">
                <div className="bg-black rounded-xl p-3 group-hover:scale-110 transition-transform">
                  <Smartphone className="w-8 h-8 text-white" />
                </div>
                <div>
                  <div className="text-lg font-semibold text-white">Download for iOS</div>
                  <div className="text-sm text-slate-400">App Store</div>
                </div>
              </Link>
            </Button>

            <Button 
              variant="outline" 
              size="lg" 
              className="h-auto py-6 px-8 border-slate-600 hover:bg-slate-800 group"
              asChild
            >
              <Link href="#" className="flex flex-col items-center space-y-2">
                <div className="bg-green-600 rounded-xl p-3 group-hover:scale-110 transition-transform">
                  <Smartphone className="w-8 h-8 text-white" />
                </div>
                <div>
                  <div className="text-lg font-semibold text-white">Download for Android</div>
                  <div className="text-sm text-slate-400">Google Play Store</div>
                </div>
              </Link>
            </Button>
          </div>
        </div>
      </section>

      {/* GitHub/Contribute Section */}
      <section id="contribute" className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl sm:text-4xl font-bold text-white mb-6">
              Join Our Community
            </h2>
            <p className="text-xl text-slate-300 max-w-3xl mx-auto">
              OpenNoiseNet is built by volunteers passionate about environmental justice. 
              Contribute code, build sensors, or help spread awareness.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-12 items-center">
            <div className="space-y-6">
              <Card className="bg-slate-800/50 border-slate-700">
                <CardHeader>
                  <CardTitle className="text-white flex items-center space-x-3">
                    <Github className="w-6 h-6" />
                    <span>Open Source Development</span>
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <CardDescription className="text-slate-300 mb-4">
                    Contribute to firmware, backend APIs, mobile apps, or hardware designs. 
                    All components are open-source under MIT/Apache 2.0 licenses.
                  </CardDescription>
                  <Button variant="outline" className="border-slate-600" asChild>
                    <Link href="https://github.com/moinsen-dev/open_noisenet" target="_blank">
                      <Github className="w-4 h-4" />
                      View Repository
                    </Link>
                  </Button>
                </CardContent>
              </Card>

              <Card className="bg-slate-800/50 border-slate-700">
                <CardHeader>
                  <CardTitle className="text-white flex items-center space-x-3">
                    <Heart className="w-6 h-6 text-red-400" />
                    <span>Community Support</span>
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <CardDescription className="text-slate-300">
                    Help others build sensors, contribute to documentation, report issues, 
                    or organize local noise awareness campaigns in your community.
                  </CardDescription>
                </CardContent>
              </Card>
            </div>

            <div className="bg-gradient-to-br from-slate-800 to-slate-900 rounded-2xl p-8 shadow-2xl">
              <h3 className="text-2xl font-bold text-white mb-6">Get Involved</h3>
              <div className="space-y-4">
                <div className="flex items-center space-x-3 text-slate-300">
                  <div className="bg-warn-500 rounded-full p-1">
                    <div className="w-2 h-2 bg-white rounded-full"></div>
                  </div>
                  <span>Build and deploy your own sensor</span>
                </div>
                <div className="flex items-center space-x-3 text-slate-300">
                  <div className="bg-warn-500 rounded-full p-1">
                    <div className="w-2 h-2 bg-white rounded-full"></div>
                  </div>
                  <span>Contribute code to improve the platform</span>
                </div>
                <div className="flex items-center space-x-3 text-slate-300">
                  <div className="bg-warn-500 rounded-full p-1">
                    <div className="w-2 h-2 bg-white rounded-full"></div>
                  </div>
                  <span>Share noise data from your neighborhood</span>
                </div>
                <div className="flex items-center space-x-3 text-slate-300">
                  <div className="bg-warn-500 rounded-full p-1">
                    <div className="w-2 h-2 bg-white rounded-full"></div>
                  </div>
                  <span>Help advocate for quieter communities</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Story Preview Section */}
      <section className="py-20 px-4 sm:px-6 lg:px-8 bg-gradient-to-r from-slate-900 to-slate-800">
        <div className="max-w-6xl mx-auto">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
            <div className="space-y-6">
              <div className="space-y-4">
                <div className="inline-block px-4 py-2 bg-warn-500/20 rounded-full border border-warn-500/30">
                  <span className="text-warn-400 text-sm font-medium">The Silent Epidemic</span>
                </div>
                <h2 className="text-3xl sm:text-4xl font-bold text-white">
                  Every Night, Millions 
                  <span className="text-warn-400 block">Struggle to Sleep</span>
                </h2>
                <p className="text-xl text-slate-300 leading-relaxed">
                  Sarah covers her ears as the garbage truck rumbles by at 3 AM. Marc holds his aching head as traffic noise pierces through his window. 
                  These aren&apos;t just inconveniences—they&apos;re public health crises.
                </p>
              </div>

              <div className="bg-slate-800/50 rounded-xl p-6 border border-slate-700">
                <div className="grid grid-cols-3 gap-4 text-center">
                  <div>
                    <div className="text-2xl font-bold text-red-400">125M</div>
                    <div className="text-xs text-slate-400">Affected Europeans</div>
                  </div>
                  <div>
                    <div className="text-2xl font-bold text-warn-400">48K</div>
                    <div className="text-xs text-slate-400">Heart Disease Cases</div>
                  </div>
                  <div>
                    <div className="text-2xl font-bold text-blue-400">€40B</div>
                    <div className="text-xs text-slate-400">Annual Health Costs</div>
                  </div>
                </div>
              </div>

              <div className="flex flex-col sm:flex-row gap-4">
                <Button 
                  variant="noise" 
                  size="lg" 
                  className="text-lg px-8 py-6 h-auto group"
                  asChild
                >
                  <Link href="/story" className="flex items-center space-x-2">
                    <span>Read Their Stories</span>
                    <div className="w-5 h-5 group-hover:translate-x-1 transition-transform">
                      →
                    </div>
                  </Link>
                </Button>
                <Button 
                  variant="ghost" 
                  size="lg" 
                  className="text-lg px-8 py-6 h-auto text-slate-400 hover:text-white"
                  asChild
                >
                  <Link href="#features">
                    See the Solution
                  </Link>
                </Button>
              </div>
            </div>

            <div className="relative">
              <div className="relative bg-gradient-to-br from-slate-800 to-slate-900 rounded-2xl p-8 shadow-2xl overflow-hidden">
                {/* Background image with overlay */}
                <div className="absolute inset-0 opacity-40">
                  <Image
                    src={getAssetPath('/onn-2.png')}
                    alt="Person affected by urban noise pollution"
                    fill
                    className="object-cover rounded-2xl"
                  />
                  <div className="absolute inset-0 bg-slate-950/60 rounded-2xl"></div>
                </div>
                
                <div className="relative z-10 space-y-6">
                  <div className="text-center">
                    <h3 className="text-2xl font-bold text-white mb-2">The Silent Epidemic</h3>
                    <p className="text-slate-300 text-sm">A story of urban noise and human resilience</p>
                  </div>
                  
                  <div className="bg-slate-900/80 rounded-lg p-4 backdrop-blur-sm">
                    <div className="flex items-center space-x-3 mb-3">
                      <div className="w-3 h-3 bg-red-400 rounded-full animate-pulse"></div>
                      <span className="text-white font-medium text-sm">Live Impact</span>
                    </div>
                    <div className="space-y-2">
                      <div className="flex justify-between text-sm">
                        <span className="text-slate-300">Current noise level</span>
                        <span className="text-red-400 font-mono">73.2 dB</span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span className="text-slate-300">Sleep disruption</span>
                        <span className="text-warn-400">High Risk</span>
                      </div>
                      <div className="w-full bg-slate-800 rounded-full h-2">
                        <div className="bg-gradient-to-r from-warn-400 to-red-400 h-2 rounded-full" style={{width: '78%'}}></div>
                      </div>
                    </div>
                  </div>

                  <div className="text-center">
                    <Link 
                      href="/story" 
                      className="text-warn-400 hover:text-warn-300 transition-colors text-sm font-medium inline-flex items-center space-x-1"
                    >
                      <span>Discover the full story</span>
                      <div className="w-4 h-4">→</div>
                    </Link>
                  </div>
                </div>
              </div>

              {/* Floating quote */}
              <div className="absolute -bottom-6 -right-6 bg-slate-950 p-4 rounded-xl border border-slate-700 max-w-xs shadow-xl">
                <blockquote className="text-slate-300 text-sm italic">
                  &quot;I haven&apos;t slept through the night in months...&quot;
                </blockquote>
                <cite className="text-slate-500 text-xs mt-2 block">— Sarah, Berlin resident</cite>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Newsletter Section */}
      <section id="newsletter" className="py-20 px-4 sm:px-6 lg:px-8 bg-slate-900/50">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-3xl sm:text-4xl font-bold text-white mb-6">
            Stay Updated
          </h2>
          <p className="text-xl text-slate-300 mb-12">
            Get the latest updates on hardware releases, software updates, and community initiatives. 
            We respect your privacy and won&apos;t spam you.
          </p>

          <Card className="bg-slate-800/50 border-slate-700 max-w-2xl mx-auto">
            <CardContent className="p-8">
              <form className="space-y-4">
                <div className="flex flex-col sm:flex-row gap-4">
                  <Input 
                    type="email" 
                    placeholder="Enter your email address"
                    className="flex-1 bg-slate-900 border-slate-600 text-white placeholder-slate-400"
                    required
                  />
                  <Button type="submit" variant="noise" className="px-8">
                    <Mail className="w-4 h-4" />
                    Subscribe
                  </Button>
                </div>
                <p className="text-xs text-slate-400">
                  By subscribing, you agree to our privacy policy. We use double opt-in and you can unsubscribe at any time.
                </p>
              </form>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-slate-950 py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-6xl mx-auto">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
            <div className="space-y-4">
              <div className="flex items-center space-x-2">
                <NoiseVisualization />
                <span className="text-xl font-bold text-white">OpenNoiseNet</span>
              </div>
              <p className="text-slate-400 text-sm">
                Democratizing environmental noise monitoring through open-source community networks.
              </p>
            </div>

            <div>
              <h4 className="text-white font-semibold mb-4">Project</h4>
              <div className="space-y-2 text-sm">
                <Link href="#features" className="block text-slate-400 hover:text-white transition-colors">
                  Features
                </Link>
                <Link href="https://github.com/moinsen-dev/open_noisenet" className="block text-slate-400 hover:text-white transition-colors">
                  GitHub
                </Link>
                <Link href="#download" className="block text-slate-400 hover:text-white transition-colors">
                  Download Apps
                </Link>
              </div>
            </div>

            <div>
              <h4 className="text-white font-semibold mb-4">Community</h4>
              <div className="space-y-2 text-sm">
                <Link href="#contribute" className="block text-slate-400 hover:text-white transition-colors">
                  Contribute
                </Link>
                <Link href="/privacy" className="block text-slate-400 hover:text-white transition-colors">
                  Privacy Policy
                </Link>
                <Link href="/terms" className="block text-slate-400 hover:text-white transition-colors">
                  Terms of Service
                </Link>
              </div>
            </div>

            <div>
              <h4 className="text-white font-semibold mb-4">Legal</h4>
              <div className="space-y-2 text-sm">
                <Link href="/imprint" className="block text-slate-400 hover:text-white transition-colors">
                  Impressum
                </Link>
                <Link href="/privacy" className="block text-slate-400 hover:text-white transition-colors">
                  Datenschutz
                </Link>
                <div className="text-slate-400">
                  GDPR/DSGVO Compliant
                </div>
              </div>
            </div>
          </div>

          <div className="border-t border-slate-800 mt-8 pt-8 text-center text-sm text-slate-400">
            <p>
              © 2024 OpenNoiseNet Community. Licensed under MIT. Data licensed under ODC-ODbL.
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}