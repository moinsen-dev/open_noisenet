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
    title: 'The Field Node',
    concept: 'A retired phone becomes an unattended sensor node',
    caption: 'Smartphone node: capture, queue, recover',
    description: 'The mobile app is being hardened into a long-running field node with local monitoring, recovery, sync diagnostics, and privacy-first uploads.',
    techFocus: 'Mobile runtime and unattended capture',
    icon: Shield,
    image: getAssetPath('/tech-1.png'),
  },
  {
    id: 'tech-2',
    title: 'The Derived-First Contract',
    concept: 'Sound enters, but cloud-default audio stays out',
    caption: 'Derived-first by default',
    description: 'OpenNoiseNet keeps numeric levels, lifecycle state, and policy-governed evidence as the default path. Raw audio is not the normal cloud artifact.',
    techFocus: 'Privacy-preserving architecture',
    icon: Shield,
    image: getAssetPath('/tech-2.png'),
  },
  {
    id: 'tech-3',
    title: 'The Event Receipt',
    concept: 'Device and server must agree on what happened',
    caption: 'event_uuid: detect, queue, upload, ACK',
    description: 'Stable identifiers, receipts, acknowledgements, and sync diagnostics let reportable events survive reconnects and be traced end to end.',
    techFocus: 'Lifecycle observability and reconciliation',
    icon: Brain,
    image: getAssetPath('/tech-3.png'),
  },
  {
    id: 'tech-4',
    title: 'The Episode Engine',
    concept: 'Raw events become reviewable incidents',
    caption: 'Event stream → episode',
    description: 'Server-side logic now groups events into episodes with severity, nuisance score, review state, and export lifecycle instead of leaving operators with raw event noise.',
    techFocus: 'Incident construction and review state',
    icon: Clock,
    image: getAssetPath('/tech-1.png'),
  },
  {
    id: 'tech-5',
    title: 'The Tenant Layer',
    concept: 'Public visibility and operator workflows stay separate',
    caption: 'Organization, site, zone, policy',
    description: 'Organizations, sites, zones, policies, and calibration profiles provide the boundary layer needed for housing and property operators without collapsing the public map into tenant data.',
    techFocus: 'Tenant context and policy boundaries',
    icon: Network,
    image: getAssetPath('/tech-2.png'),
  },
  {
    id: 'tech-6',
    title: 'The Operator Workflow',
    concept: 'Review, case, export',
    caption: 'Inbox, case detail, evidence package',
    description: 'The dashboard now contains the first operator surfaces for episode review, case creation, and PDF/CSV/JSON export, aimed at early housing and property workflows.',
    techFocus: 'Operator product and evidence handling',
    icon: BarChart,
    image: getAssetPath('/tech-3.png'),
  },
  {
    id: 'tech-7',
    title: 'The Stabilization Gate',
    concept: 'Trust before scale',
    caption: '24h/72h field validation first',
    description: 'Before self-serve beta or broader commercialization, the platform still has to prove unattended mobile reliability, clean Docker operations, and deterministic demos.',
    techFocus: 'Runtime trust and release gating',
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
              <span>Back to Home</span>
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
            <span className="text-warn-400 block">Behind Public + Pro</span>
          </h1>
          <p className="text-xl md:text-2xl text-slate-300 mb-12 leading-relaxed max-w-4xl mx-auto">
            How OpenNoiseNet is turning smartphone field nodes, public visibility, and operator evidence workflows into one privacy-first noise monitoring platform
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
              <Link href="/">
                Back to Home
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
              Current Technical Building Blocks
            </h2>
            <p className="text-xl text-slate-300 max-w-3xl mx-auto">
              Seven parts of the architecture that are already in motion while the stabilization gate remains open
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
              Execution <span className="text-warn-400">Priorities</span>
            </h2>
            <p className="text-xl text-slate-300 max-w-3xl mx-auto">
              Honest architecture means showing both what already exists and what still has to be hardened
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
                  Derived-only remains the default posture. The active architecture work is designed so that public visibility and operator evidence workflows do not depend on cloud-default audio storage.
                </p>
              </div>

              <div className="bg-slate-800/60 rounded-2xl p-8 border border-slate-700">
                <h3 className="text-2xl font-bold text-white mb-4 flex items-center gap-3">
                  <Network className="w-6 h-6 text-blue-400" />
                  Active Gate
                </h3>
                <p className="text-slate-300 leading-relaxed">
                  The immediate goal is unattended mobile reliability, quiet Docker and monitoring behavior, and a deterministic event → episode → case → export baseline suitable for demos and pilots.
                </p>
              </div>
            </div>

            <div className="relative">
              <div className="bg-slate-800 rounded-2xl p-8 shadow-2xl">
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-slate-300">Public Layer</span>
                    <span className="text-green-400 font-mono text-lg">Live MVP</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-slate-300">Pro Domain</span>
                    <span className="text-warn-400 font-mono text-lg">Implemented</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-slate-300">Episodes / Cases / Exports</span>
                    <span className="text-warn-400 font-mono text-lg">Hardening</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-slate-300">Mobile Field Node</span>
                    <span className="text-blue-400 font-mono text-lg">Validation</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-slate-300">Self-Serve Beta</span>
                    <span className="text-slate-400 font-mono text-lg">Not started</span>
                  </div>
                  <div className="pt-4 border-t border-slate-700">
                    <div className="flex items-center gap-2 mb-2">
                      <div className="w-3 h-3 bg-warn-400 rounded-full animate-pulse"></div>
                      <span className="text-white font-semibold">Current Program Status</span>
                    </div>
                    <div className="w-full bg-slate-700 rounded-full h-2">
                      <div className="bg-gradient-to-r from-blue-400 via-warn-400 to-green-400 h-2 rounded-full w-2/3 animate-pulse"></div>
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
            Help Finish the
            <span className="text-warn-400 block">Platform</span>
          </h2>
          <p className="text-xl md:text-2xl text-slate-300 mb-12 max-w-4xl mx-auto leading-relaxed">
            The hardest work now is reliability, hardening, and turning the existing public + Pro slices into a trustworthy pilot baseline.
          </p>

          <div className="flex flex-col sm:flex-row gap-6 justify-center mb-12">
            <Button 
              variant="noise" 
              size="lg" 
              className="text-xl px-12 py-8 h-auto"
              asChild
            >
              <Link href="https://github.com/moinsen-dev/open_noisenet" target="_blank">
                View Source Code
              </Link>
            </Button>
            <Button 
              variant="outline" 
              size="lg" 
              className="text-xl px-12 py-8 h-auto border-slate-600 hover:bg-slate-800"
              asChild
            >
              <Link href="/">
                Back to Home
              </Link>
            </Button>
          </div>

          <div className="bg-slate-800/60 rounded-2xl p-8 border border-slate-700 max-w-4xl mx-auto">
            <h3 className="text-2xl font-bold text-white mb-4">Ready to Make an Impact?</h3>
            <p className="text-slate-300 mb-6">
              Follow the repo, validate the field node, and help make the operator workflow trustworthy enough for early pilots.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Button variant="outline" className="border-warn-400 text-warn-400 hover:bg-warn-400 hover:text-white" asChild>
                <Link href="/story">Read the Story</Link>
              </Button>
              <Button variant="outline" className="border-slate-600 hover:bg-slate-700" asChild>
                <Link href="/#access">See Access Paths</Link>
              </Button>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
