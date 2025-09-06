'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { getAssetPath } from '@/lib/asset-path';
import { Button } from '@/components/ui/button';
import NoiseVisualization from '@/components/noise-visualization';
import { markStoryAsSeen, setSkipStoryPreference } from '@/lib/cookies';
import { ArrowLeft, ChevronDown, Volume2, Heart, Shield, Users, X, Home } from 'lucide-react';

export default function StoryPage() {
  const [scrollY, setScrollY] = useState(0);
  const [currentChapter, setCurrentChapter] = useState(0);
  const [showSkipDialog, setShowSkipDialog] = useState(false);
  const router = useRouter();

  useEffect(() => {
    const handleScroll = () => {
      if (typeof window === 'undefined') return;
      
      setScrollY(window.scrollY);
      
      // Calculate current chapter based on scroll position
      const chapter = Math.floor(window.scrollY / window.innerHeight);
      setCurrentChapter(Math.min(chapter, 5));
    };

    if (typeof window !== 'undefined') {
      window.addEventListener('scroll', handleScroll);
      return () => window.removeEventListener('scroll', handleScroll);
    }
  }, []);

  const scrollToChapter = (chapter: number) => {
    if (typeof window === 'undefined') return;
    
    window.scrollTo({
      top: chapter * window.innerHeight,
      behavior: 'smooth'
    });
  };

  const handleStoryComplete = () => {
    markStoryAsSeen();
    router.push('/');
  };

  const handleSkipStory = () => {
    setSkipStoryPreference(true);
    router.push('/');
  };

  const handleSkipConfirm = () => {
    setShowSkipDialog(false);
    handleSkipStory();
  };

  return (
    <div className="min-h-screen bg-slate-950">
      {/* Navigation */}
      <nav className="fixed top-0 left-0 right-0 z-50 bg-slate-950/80 backdrop-blur-md border-b border-slate-800">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <Link href="/" className="flex items-center space-x-2 text-white hover:text-warn-400 transition-colors">
              <ArrowLeft className="w-5 h-5" />
              <span>Back to Home</span>
            </Link>
            <div className="flex items-center space-x-2">
              <NoiseVisualization />
              <span className="text-xl font-bold text-white">OpenNoiseNet</span>
            </div>
            <div className="flex items-center space-x-4">
              <div className="text-slate-400 text-sm">
                Chapter {currentChapter + 1} of 6
              </div>
              <button
                onClick={() => setShowSkipDialog(true)}
                className="text-slate-400 hover:text-white transition-colors text-sm flex items-center space-x-1"
              >
                <X className="w-4 h-4" />
                <span>Skip Story</span>
              </button>
            </div>
          </div>
        </div>
      </nav>

      {/* Skip Story Dialog */}
      {showSkipDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm">
          <div className="bg-slate-900 rounded-xl p-8 max-w-md mx-4 border border-slate-700">
            <h3 className="text-xl font-bold text-white mb-4">Skip the Story?</h3>
            <p className="text-slate-300 mb-6">
              This story helps explain why OpenNoiseNet matters for communities worldwide. 
              You can always read it later from the menu.
            </p>
            <div className="flex space-x-4">
              <Button 
                variant="outline" 
                onClick={() => setShowSkipDialog(false)}
                className="flex-1 border-slate-600"
              >
                Continue Reading
              </Button>
              <Button 
                variant="noise" 
                onClick={handleSkipConfirm}
                className="flex-1"
              >
                Skip to Homepage
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* Progress Indicator */}
      <div className="fixed left-6 top-1/2 transform -translate-y-1/2 z-40 hidden lg:flex flex-col space-y-2">
        {[0, 1, 2, 3, 4, 5].map((chapter) => (
          <button
            key={chapter}
            onClick={() => scrollToChapter(chapter)}
            className={`w-3 h-3 rounded-full transition-all duration-300 ${
              currentChapter === chapter 
                ? 'bg-warn-400 scale-125' 
                : 'bg-slate-600 hover:bg-slate-500'
            }`}
            title={`Go to Chapter ${chapter + 1}`}
          />
        ))}
      </div>

      {/* Chapter 1: The Night Should Be Peaceful */}
      <section className="relative h-screen flex items-center justify-center overflow-hidden">
        <div 
          className="absolute inset-0 z-0"
          style={{
            transform: `translateY(${scrollY * 0.5}px)`,
          }}
        >
          <Image
            src={getAssetPath('/onn-7.png')}
            alt="Phone monitoring noise by rainy window at night"
            fill
            className="object-cover"
            priority
          />
          <div className="absolute inset-0 bg-slate-950/60" />
        </div>
        
        {/* Rain animation overlay */}
        <div className="absolute inset-0 z-10 rain-animation"></div>
        
        <div className="relative z-20 text-center max-w-4xl mx-auto px-4">
          <h1 className="text-5xl md:text-7xl font-bold text-white mb-8 leading-tight">
            The Silent 
            <span className="text-warn-400 block">Epidemic</span>
          </h1>
          <p className="text-xl md:text-2xl text-slate-300 mb-12 leading-relaxed">
            In cities worldwide, millions try to rest. But the night is no longer silent...
          </p>
          <div className="flex justify-center">
            <ChevronDown 
              className="w-8 h-8 text-warn-400 animate-bounce cursor-pointer"
              onClick={() => scrollToChapter(1)}
            />
          </div>
        </div>
      </section>

      {/* Chapter 2: When Sleep Becomes a Luxury */}
      <section className="relative h-screen flex items-center justify-center overflow-hidden">
        <div 
          className="absolute inset-0 z-0"
          style={{
            transform: `translateY(${(scrollY - (typeof window !== 'undefined' ? window.innerHeight : 800)) * 0.3}px)`,
          }}
        >
          <Image
            src={getAssetPath('/onn-2.png')}
            alt="Person covering ears from garbage truck noise at night"
            fill
            className="object-cover"
          />
          <div className="absolute inset-0 bg-slate-950/70" />
        </div>

        {/* Sound waves animation */}
        <div className="absolute right-4 top-1/2 transform -translate-y-1/2 z-10">
          <div className="flex space-x-1">
            {[1, 2, 3, 4, 5].map((i) => (
              <div
                key={i}
                className="w-1 bg-warn-400 rounded-full sound-wave"
                style={{
                  height: `${20 + i * 10}px`,
                  animationDelay: `${i * 0.1}s`,
                }}
              />
            ))}
          </div>
        </div>
        
        <div className="relative z-20 max-w-4xl mx-auto px-4">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
            <div>
              <h2 className="text-4xl md:text-5xl font-bold text-white mb-6">
                When Sleep Becomes a 
                <span className="text-warn-400">Luxury</span>
              </h2>
              <p className="text-lg md:text-xl text-slate-300 mb-8 leading-relaxed">
                3 AM. The garbage truck arrives. Every night. Same time. 
                Sarah hasn&apos;t slept through the night in months.
              </p>
              <div className="bg-slate-900/80 rounded-xl p-6 border border-slate-700">
                <div className="flex items-center space-x-3 mb-4">
                  <Volume2 className="w-6 h-6 text-red-400" />
                  <h3 className="text-xl font-semibold text-white">Nighttime Noise Levels</h3>
                </div>
                <div className="space-y-3">
                  <div className="flex justify-between items-center">
                    <span className="text-slate-300">WHO Recommendation</span>
                    <span className="text-green-400 font-medium">≤30 dB</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-slate-300">Garbage Truck</span>
                    <span className="text-red-400 font-medium">85+ dB</span>
                  </div>
                  <div className="w-full bg-slate-800 rounded-full h-2">
                    <div className="bg-gradient-to-r from-green-400 to-red-400 h-2 rounded-full" style={{width: '75%'}}></div>
                  </div>
                </div>
              </div>
            </div>
            <div className="lg:flex hidden justify-center">
              <div className="text-center space-y-4">
                <div className="bg-slate-900/80 rounded-full p-6 mx-auto w-fit border border-slate-700">
                  <Heart className="w-12 h-12 text-red-400" />
                </div>
                <p className="text-slate-400 text-sm max-w-xs">
                  Sleep disruption affects cardiovascular health, immune system, and mental wellbeing
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Chapter 3: The Hidden Toll */}
      <section className="relative h-screen flex items-center justify-center overflow-hidden">
        <div 
          className="absolute inset-0 z-0"
          style={{
            transform: `translateY(${(scrollY - (typeof window !== 'undefined' ? window.innerHeight : 800) * 2) * 0.2}px)`,
          }}
        >
          <Image
            src={getAssetPath('/onn-5.png')}
            alt="Man suffering from headache due to traffic noise"
            fill
            className="object-cover"
          />
          <div className="absolute inset-0 bg-slate-950/75" />
        </div>
        
        <div className="relative z-20 max-w-6xl mx-auto px-4">
          <div className="text-center mb-12">
            <h2 className="text-4xl md:text-5xl font-bold text-white mb-6">
              The Hidden 
              <span className="text-warn-400">Toll</span>
            </h2>
            <p className="text-xl md:text-2xl text-slate-300 mb-8 max-w-3xl mx-auto leading-relaxed">
              Chronic noise exposure leads to stress, cardiovascular problems, and cognitive decline. 
              Marc is 35 but feels 50.
            </p>
          </div>

          {/* Health Impact Stats */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="bg-slate-900/80 rounded-xl p-6 border border-slate-700 text-center">
              <div className="text-3xl font-bold text-red-400 mb-2">125M</div>
              <p className="text-slate-300">Europeans exposed to harmful noise levels</p>
            </div>
            <div className="bg-slate-900/80 rounded-xl p-6 border border-slate-700 text-center">
              <div className="text-3xl font-bold text-warn-400 mb-2">48,000</div>
              <p className="text-slate-300">Annual cases of heart disease from noise</p>
            </div>
            <div className="bg-slate-900/80 rounded-xl p-6 border border-slate-700 text-center">
              <div className="text-3xl font-bold text-blue-400 mb-2">€40B</div>
              <p className="text-slate-300">Annual health costs in EU alone</p>
            </div>
          </div>

          {/* WHO Quote */}
          <div className="mt-12 bg-slate-800/60 rounded-xl p-8 border-l-4 border-warn-400">
            <blockquote className="text-lg md:text-xl text-slate-300 italic mb-4">
              &quot;Noise pollution is not just an environmental issue – it&apos;s a public health crisis 
              that affects millions of people worldwide.&quot;
            </blockquote>
            <cite className="text-slate-400">— World Health Organization</cite>
          </div>
        </div>
      </section>

      {/* Chapter 4: Technology Meets Compassion */}
      <section className="relative h-screen flex items-center justify-center overflow-hidden bg-slate-900">
        <div 
          className="absolute inset-0 z-0"
          style={{
            transform: `translateY(${(scrollY - (typeof window !== 'undefined' ? window.innerHeight : 800) * 3) * 0.1}px)`,
          }}
        >
          <Image
            src={getAssetPath('/onn-1.png')}
            alt="OpenNoiseNet app interface showing noise monitoring"
            fill
            className="object-contain opacity-20"
          />
        </div>
        
        <div className="relative z-20 max-w-6xl mx-auto px-4">
          <div className="text-center mb-12">
            <h2 className="text-4xl md:text-5xl font-bold text-white mb-6">
              Technology Meets 
              <span className="text-warn-400">Compassion</span>
            </h2>
            <p className="text-xl md:text-2xl text-slate-300 mb-8 max-w-4xl mx-auto leading-relaxed">
              OpenNoiseNet was born from frustration, built with hope. 
              Every sensor tells a story. Every data point demands action.
            </p>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
            <div className="space-y-6">
              <div className="bg-slate-800/60 rounded-xl p-6 border border-slate-700">
                <div className="flex items-center space-x-3 mb-4">
                  <Shield className="w-6 h-6 text-green-400" />
                  <h3 className="text-xl font-semibold text-white">Privacy First</h3>
                </div>
                <p className="text-slate-300">
                  Default sensors collect only sound levels, not conversations. Your privacy is protected by design.
                </p>
              </div>

              <div className="bg-slate-800/60 rounded-xl p-6 border border-slate-700">
                <div className="flex items-center space-x-3 mb-4">
                  <Users className="w-6 h-6 text-blue-400" />
                  <h3 className="text-xl font-semibold text-white">Community Driven</h3>
                </div>
                <p className="text-slate-300">
                  Built by volunteers who believe everyone deserves peaceful neighborhoods and restful nights.
                </p>
              </div>
            </div>

            <div className="flex justify-center">
              <div className="relative">
                <div className="bg-slate-800 rounded-2xl p-8 shadow-2xl">
                  <Image
                    src={getAssetPath('/onn-1.png')}
                    alt="OpenNoiseNet App Interface"
                    width={300}
                    height={300}
                    className="rounded-xl"
                  />
                </div>
                {/* Floating icons animation */}
                <div className="absolute -top-4 -left-4 bg-warn-500 p-3 rounded-full animate-pulse">
                  <Volume2 className="w-6 h-6 text-white" />
                </div>
                <div className="absolute -bottom-4 -right-4 bg-noise-500 p-3 rounded-full animate-bounce">
                  <Shield className="w-6 h-6 text-white" />
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Chapter 5: Silent Witnesses */}
      <section className="relative h-screen flex items-center justify-center overflow-hidden">
        <div 
          className="absolute inset-0 z-0"
          style={{
            transform: `translateY(${(scrollY - (typeof window !== 'undefined' ? window.innerHeight : 800) * 4) * 0.3}px)`,
          }}
        >
          <Image
            src={getAssetPath('/onn-3.png')}
            alt="Monitoring device by window capturing noise data"
            fill
            className="object-cover"
          />
          <div className="absolute inset-0 bg-slate-950/70" />
        </div>
        
        <div className="relative z-20 max-w-5xl mx-auto px-4">
          <div className="text-center mb-12">
            <h2 className="text-4xl md:text-5xl font-bold text-white mb-6">
              Silent 
              <span className="text-warn-400">Witnesses</span>
            </h2>
            <p className="text-xl md:text-2xl text-slate-300 mb-8 max-w-3xl mx-auto leading-relaxed">
              24/7, our community sensors stand guard. Collecting evidence. Building the case for quieter cities.
            </p>
          </div>

          {/* Live Data Simulation */}
          <div className="bg-slate-900/90 rounded-xl p-8 border border-slate-700">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-8">
              <div className="text-center">
                <div className="text-3xl font-bold text-green-400 mb-2">1,247</div>
                <p className="text-slate-300">Active Sensors</p>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-blue-400 mb-2">156M</div>
                <p className="text-slate-300">Data Points Collected</p>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-warn-400 mb-2">23</div>
                <p className="text-slate-300">Cities Participating</p>
              </div>
            </div>

            <div className="bg-slate-800 rounded-lg p-4">
              <h3 className="text-lg font-semibold text-white mb-4 flex items-center">
                <div className="w-3 h-3 bg-green-400 rounded-full mr-2 animate-pulse"></div>
                Live Monitoring
              </h3>
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-slate-300">Current Average</span>
                  <span className="text-warn-400 font-mono">52.3 dB</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-slate-300">Peak Today</span>
                  <span className="text-red-400 font-mono">78.9 dB</span>
                </div>
                <div className="w-full bg-slate-700 rounded-full h-2">
                  <div className="bg-gradient-to-r from-green-400 via-warn-400 to-red-400 h-2 rounded-full animate-pulse" style={{width: '60%'}}></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Chapter 6: Join the Quiet Revolution */}
      <section className="relative h-screen flex items-center justify-center bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950">
        <div className="relative z-20 max-w-6xl mx-auto px-4 text-center">
          <h2 className="text-5xl md:text-6xl font-bold text-white mb-8">
            Join the Quiet 
            <span className="text-warn-400">Revolution</span>
          </h2>
          <p className="text-xl md:text-2xl text-slate-300 mb-12 max-w-4xl mx-auto leading-relaxed">
            Every sensor matters. Every measurement counts. Every voice makes a difference. 
            Help us build a world where peace and quiet aren&apos;t luxuries.
          </p>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-12">
            <div className="bg-slate-800/60 rounded-xl p-8 border border-slate-700 hover:border-warn-400 transition-colors group">
              <div className="bg-warn-500 p-4 rounded-full w-fit mx-auto mb-4 group-hover:scale-110 transition-transform">
                <Volume2 className="w-8 h-8 text-white" />
              </div>
              <h3 className="text-xl font-semibold text-white mb-4">Build a Sensor</h3>
              <p className="text-slate-300 mb-6">
                Create your own noise monitoring device for just €30-45 with our DIY guide.
              </p>
              <Button variant="outline" className="border-warn-400 text-warn-400 hover:bg-warn-400 hover:text-white">
                Get Started
              </Button>
            </div>

            <div className="bg-slate-800/60 rounded-xl p-8 border border-slate-700 hover:border-noise-400 transition-colors group">
              <div className="bg-noise-500 p-4 rounded-full w-fit mx-auto mb-4 group-hover:scale-110 transition-transform">
                <Users className="w-8 h-8 text-white" />
              </div>
              <h3 className="text-xl font-semibold text-white mb-4">Join the Community</h3>
              <p className="text-slate-300 mb-6">
                Connect with fellow advocates, share data, and campaign for policy changes.
              </p>
              <Button variant="outline" className="border-noise-400 text-noise-400 hover:bg-noise-400 hover:text-white">
                Get Involved
              </Button>
            </div>

            <div className="bg-slate-800/60 rounded-xl p-8 border border-slate-700 hover:border-green-400 transition-colors group">
              <div className="bg-green-500 p-4 rounded-full w-fit mx-auto mb-4 group-hover:scale-110 transition-transform">
                <Shield className="w-8 h-8 text-white" />
              </div>
              <h3 className="text-xl font-semibold text-white mb-4">Use the Data</h3>
              <p className="text-slate-300 mb-6">
                Access open data for research, advocacy, and community awareness campaigns.
              </p>
              <Button variant="outline" className="border-green-400 text-green-400 hover:bg-green-400 hover:text-white">
                Explore Data
              </Button>
            </div>
          </div>

          <div className="flex flex-col sm:flex-row gap-4 justify-center mb-8">
            <Button 
              variant="noise" 
              size="lg" 
              className="text-lg px-8 py-6 h-auto"
              asChild
            >
              <Link href="/#download">
                Download Our Apps
              </Link>
            </Button>
            <Button 
              variant="outline" 
              size="lg" 
              className="text-lg px-8 py-6 h-auto border-slate-600 hover:bg-slate-800"
              asChild
            >
              <Link href="https://github.com/moinsen-dev/open_noisenet" target="_blank">
                View on GitHub
              </Link>
            </Button>
          </div>

          {/* Story Complete - Continue to Homepage */}
          <div className="bg-slate-800/60 rounded-2xl p-8 border border-slate-700 text-center mb-8">
            <div className="space-y-6">
              <div>
                <div className="bg-green-500 p-4 rounded-full w-fit mx-auto mb-4">
                  <Heart className="w-8 h-8 text-white" />
                </div>
                <h3 className="text-2xl font-bold text-white mb-2">Thank You for Reading</h3>
                <p className="text-slate-300 max-w-2xl mx-auto">
                  You&apos;ve discovered the human story behind OpenNoiseNet. 
                  Every sensor deployed helps build quieter, healthier communities worldwide.
                </p>
              </div>

              <div className="flex flex-col sm:flex-row gap-4 justify-center">
                <Button 
                  onClick={handleStoryComplete}
                  variant="noise" 
                  size="lg" 
                  className="text-lg px-8 py-6 h-auto group"
                >
                  <Home className="w-5 h-5 mr-2 group-hover:scale-110 transition-transform" />
                  Continue to Homepage
                </Button>
                <Button 
                  variant="outline" 
                  size="lg" 
                  className="text-lg px-8 py-6 h-auto border-slate-600 hover:bg-slate-800"
                  onClick={() => scrollToChapter(0)}
                >
                  ↑ Read Story Again
                </Button>
              </div>

              <p className="text-xs text-slate-500">
                We&apos;ve saved your preference - you won&apos;t see this story automatically again.
              </p>
            </div>
          </div>

          {/* Back to top */}
          <div className="mt-8">
            <button 
              onClick={() => scrollToChapter(0)}
              className="text-slate-400 hover:text-warn-400 transition-colors"
            >
              ↑ Back to Top
            </button>
          </div>
        </div>
      </section>
    </div>
  );
}