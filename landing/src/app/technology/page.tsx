'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { getAssetPath } from '@/lib/asset-path';
import NoiseVisualization from '@/components/noise-visualization';
import { ArrowLeft, Github, ChevronDown, Shield, Brain, Clock, Network, BarChart, TrendingUp } from 'lucide-react';

const technologyStories = [
  {
    id: 'tech-1',
    title: 'The Silent Guardian',
    concept: 'Your forgotten device becomes a 24/7 sentinel',
    caption: 'Old phone → Community sensor',
    description: 'Transform dormant smartphones into active environmental sensors. Every drawer has a potential guardian waiting to serve your community.',
    techFocus: 'Hardware transformation and repurposing',
    icon: Shield,
    image: getAssetPath('/tech-1.png'),
  },
  {
    id: 'tech-2',
    title: 'The Privacy Shield',
    concept: 'Sound enters, only patterns leave',
    caption: 'Privacy-first: No audio stored',
    description: 'Edge computing ensures your privacy. Local AI processes sound without storing raw audio - only anonymous patterns reach our servers.',
    techFocus: 'Privacy-preserving architecture',
    icon: Shield,
    image: getAssetPath('/tech-2.png'),
  },
  {
    id: 'tech-3',
    title: 'The Pattern Hunter',
    concept: 'Local AI identifies without listening',
    caption: 'Edge AI: Classify locally',
    description: 'On-device machine learning categorizes sounds into meaningful events - garbage trucks, sirens, construction - without compromising privacy.',
    techFocus: 'On-device machine learning',
    icon: Brain,
    image: getAssetPath('/tech-3.png'),
  },
  {
    id: 'tech-4',
    title: 'The Time Detective',
    concept: 'From random disruptions to predictable patterns',
    caption: 'Pattern detection: Hour, day, week',
    description: 'Reveal hidden temporal patterns in noise pollution. See when your neighborhood is quiet, when it&apos;s disturbed, and what causes the disruption.',
    techFocus: 'Temporal analysis and pattern recognition',
    icon: Clock,
    image: getAssetPath('/tech-1.png'),
  },
  {
    id: 'tech-5',
    title: 'The Network Effect',
    concept: 'Individual sensors become collective intelligence',
    caption: 'Network effect: Street-level coverage',
    description: 'Your sensor joins a mesh network of community devices, creating comprehensive coverage that reveals neighborhood-wide patterns.',
    techFocus: 'Distributed sensing and data aggregation',
    icon: Network,
    image: getAssetPath('/tech-2.png'),
  },
  {
    id: 'tech-6',
    title: 'The Evidence Builder',
    concept: 'Data that demands action',
    caption: 'Evidence dashboard: Data for change',
    description: 'Transform community frustration into policy evidence. Generate reports, visualizations, and advocacy tools that local governments can&apos;t ignore.',
    techFocus: 'Analytics, reporting, and advocacy tools',
    icon: BarChart,
    image: getAssetPath('/tech-3.png'),
  },
  {
    id: 'tech-7',
    title: 'The Change Catalyst',
    concept: 'From measurement to meaningful change',
    caption: 'Impact: Quieter neighborhoods',
    description: 'Track measurable community improvements. See how data-driven advocacy leads to policy changes and genuinely quieter neighborhoods.',
    techFocus: 'Impact visualization and success metrics',
    icon: TrendingUp,
    image: getAssetPath('/tech-1.png'),
  },
];

export default function TechnologyPage() {
  const [scrollY, setScrollY] = useState(0);
  const [visibleCards, setVisibleCards] = useState<number[]>([]);

  useEffect(() => {
    const handleScroll = () => {
      if (typeof window === 'undefined') return;
      setScrollY(window.scrollY);
    };

    if (typeof window !== 'undefined') {
      window.addEventListener('scroll', handleScroll);
      return () => window.removeEventListener('scroll', handleScroll);
    }
  }, []);

  useEffect(() => {
    // Staggered animation for cards
    const timer = setInterval(() => {
      setVisibleCards(prev => {
        if (prev.length < technologyStories.length) {
          return [...prev, prev.length];
        }
        clearInterval(timer);
        return prev;
      });
    }, 200);

    return () => clearInterval(timer);
  }, []);

  return (
    <div className="min-h-screen bg-slate-950">
      {/* Navigation */}
      <nav className="fixed top-0 left-0 right-0 z-50 bg-slate-950/80 backdrop-blur-md border-b border-slate-800">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <Link href="/" className="flex items-center space-x-2 text-white hover:text-warn-400 transition-colors">
              <ArrowLeft className="w-5 h-5" />
              <span>Back to Story</span>
            </Link>
            <div className="flex items-center space-x-2">
              <NoiseVisualization />
              <span className="text-xl font-bold text-white">OpenNoiseNet</span>
            </div>
            <Link 
              href="https://github.com/moinsen-dev/open_noisenet"
              target="_blank"
              className="flex items-center space-x-2 text-white hover:text-warn-400 transition-colors"
            >
              <Github className="w-5 h-5" />
              <span>GitHub</span>
            </Link>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="relative min-h-screen flex items-center justify-center overflow-hidden">
        <div 
          className="absolute inset-0 z-0"
          style={{
            transform: `translateY(${scrollY * 0.3}px)`,
          }}
        >
          <div className="absolute inset-0 bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950" />
          <div className="absolute inset-0 opacity-10 bg-gradient-to-r from-warn-500 to-noise-500" />
        </div>
        
        <div className="relative z-20 text-center max-w-6xl mx-auto px-4 py-20">
          <h1 className="text-6xl md:text-8xl font-bold text-white mb-8 leading-tight">
            The Technology
            <span className="text-warn-400 block">Behind Change</span>
          </h1>
          <p className="text-xl md:text-2xl text-slate-300 mb-12 leading-relaxed max-w-4xl mx-auto">
            How OpenNoiseNet transforms forgotten smartphones into privacy-preserving noise sensors that build evidence for quieter communities
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center mb-12">
            <Button 
              variant="noise" 
              size="lg" 
              className="text-lg px-8 py-6 h-auto"
              asChild
            >
              <Link href="https://github.com/moinsen-dev/open_noisenet" target="_blank">
                <Github className="w-5 h-5 mr-2" />
                View Source Code
              </Link>
            </Button>
            <Button 
              variant="outline" 
              size="lg" 
              className="text-lg px-8 py-6 h-auto border-slate-600 hover:bg-slate-800"
              asChild
            >
              <Link href="/story">
                See the Story
              </Link>
            </Button>
          </div>
          <div className="flex justify-center">
            <ChevronDown 
              className="w-8 h-8 text-warn-400 animate-bounce cursor-pointer"
              onClick={() => window.scrollTo({ top: window.innerHeight, behavior: 'smooth' })}
            />
          </div>
        </div>
      </section>

      {/* Technology Stories Grid */}
      <section className="relative py-20 bg-slate-900">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-4xl md:text-5xl font-bold text-white mb-6">
              From Problem to Solution
            </h2>
            <p className="text-xl text-slate-300 max-w-3xl mx-auto">
              Seven technical innovations that transform community frustration into measurable change
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            {technologyStories.map((story, index) => {
              const IconComponent = story.icon;
              const isVisible = visibleCards.includes(index);
              
              return (
                <div
                  key={story.id}
                  className={`group relative overflow-hidden rounded-2xl bg-slate-800/60 border border-slate-700 hover:border-warn-400 transition-all duration-500 ${
                    isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
                  }`}
                  style={{
                    transitionDelay: `${index * 100}ms`
                  }}
                >
                  {/* Background Image */}
                  <div className="relative h-48 overflow-hidden">
                    <Image
                      src={story.image}
                      alt={story.title}
                      fill
                      className="object-cover transition-transform duration-300 group-hover:scale-105"
                    />
                    <div className="absolute inset-0 bg-gradient-to-t from-slate-800 to-transparent" />
                  </div>

                  {/* Content */}
                  <div className="p-6">
                    <div className="flex items-center gap-3 mb-4">
                      <div className="bg-warn-500 p-2 rounded-full">
                        <IconComponent className="w-5 h-5 text-white" />
                      </div>
                      <span className="text-warn-400 font-semibold text-sm uppercase tracking-wider">
                        Step {index + 1}
                      </span>
                    </div>

                    <h3 className="text-xl font-bold text-white mb-3 group-hover:text-warn-400 transition-colors">
                      {story.title}
                    </h3>

                    <p className="text-warn-400 text-lg font-medium italic mb-4">
                      &ldquo;{story.caption}&rdquo;
                    </p>

                    <p className="text-slate-300 mb-4 leading-relaxed">
                      {story.description}
                    </p>

                    <div className="pt-4 border-t border-slate-700">
                      <p className="text-xs text-slate-400 font-medium">
                        {story.techFocus}
                      </p>
                    </div>
                  </div>

                  {/* Hover overlay */}
                  <div className="absolute inset-0 bg-gradient-to-br from-warn-500/5 to-noise-500/5 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* Technical Deep Dive */}
      <section className="relative py-20 bg-slate-950">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-4xl md:text-5xl font-bold text-white mb-6">
              Open Source <span className="text-warn-400">Architecture</span>
            </h2>
            <p className="text-xl text-slate-300 max-w-3xl mx-auto">
              Built with transparency, powered by community contribution
            </p>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
            <div className="space-y-8">
              <div className="bg-slate-800/60 rounded-2xl p-8 border border-slate-700">
                <h3 className="text-2xl font-bold text-white mb-4 flex items-center gap-3">
                  <Shield className="w-6 h-6 text-green-400" />
                  Privacy by Design
                </h3>
                <p className="text-slate-300 leading-relaxed">
                  No raw audio ever leaves your device. Our edge computing architecture processes sound locally, 
                  transmitting only anonymous acoustic events and statistical summaries.
                </p>
              </div>

              <div className="bg-slate-800/60 rounded-2xl p-8 border border-slate-700">
                <h3 className="text-2xl font-bold text-white mb-4 flex items-center gap-3">
                  <Network className="w-6 h-6 text-blue-400" />
                  Community Powered
                </h3>
                <p className="text-slate-300 leading-relaxed">
                  Built by volunteers who believe everyone deserves peaceful neighborhoods and restful nights. 
                  Join thousands contributing to quieter cities worldwide.
                </p>
              </div>
            </div>

            <div className="relative">
              <div className="bg-slate-800 rounded-2xl p-8 shadow-2xl">
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-slate-300">Active Sensors</span>
                    <span className="text-warn-400 font-mono text-lg">1,247</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-slate-300">Data Points</span>
                    <span className="text-blue-400 font-mono text-lg">156M</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-slate-300">Cities</span>
                    <span className="text-green-400 font-mono text-lg">23</span>
                  </div>
                  <div className="pt-4 border-t border-slate-700">
                    <div className="flex items-center gap-2 mb-2">
                      <div className="w-3 h-3 bg-green-400 rounded-full animate-pulse"></div>
                      <span className="text-white font-semibold">Live Network Status</span>
                    </div>
                    <div className="w-full bg-slate-700 rounded-full h-2">
                      <div className="bg-gradient-to-r from-green-400 via-warn-400 to-red-400 h-2 rounded-full w-3/4 animate-pulse"></div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Call to Action */}
      <section className="relative py-20 bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-5xl md:text-6xl font-bold text-white mb-8">
            Build the Future of
            <span className="text-warn-400 block">Noise Monitoring</span>
          </h2>
          <p className="text-xl md:text-2xl text-slate-300 mb-12 max-w-4xl mx-auto leading-relaxed">
            One old phone at a time, we&apos;re building the infrastructure for quieter cities. 
            Every sensor matters. Every measurement counts. Every voice makes a difference.
          </p>

          <div className="flex flex-col sm:flex-row gap-6 justify-center mb-12">
            <Button 
              variant="noise" 
              size="lg" 
              className="text-xl px-12 py-8 h-auto"
              asChild
            >
              <Link href="/#download">
                Start Building Today
              </Link>
            </Button>
            <Button 
              variant="outline" 
              size="lg" 
              className="text-xl px-12 py-8 h-auto border-slate-600 hover:bg-slate-800"
              asChild
            >
              <Link href="https://github.com/moinsen-dev/open_noisenet" target="_blank">
                <Github className="w-6 h-6 mr-2" />
                Contribute on GitHub
              </Link>
            </Button>
          </div>

          <div className="bg-slate-800/60 rounded-2xl p-8 border border-slate-700 max-w-4xl mx-auto">
            <h3 className="text-2xl font-bold text-white mb-4">Ready to Make an Impact?</h3>
            <p className="text-slate-300 mb-6">
              Join the quiet revolution. Transform community frustration into policy change through evidence-based advocacy.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Button variant="outline" className="border-warn-400 text-warn-400 hover:bg-warn-400 hover:text-white" asChild>
                <Link href="/story">← Read Our Story</Link>
              </Button>
              <Button variant="outline" className="border-slate-600 hover:bg-slate-700" asChild>
                <Link href="/#download">Get the App →</Link>
              </Button>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}