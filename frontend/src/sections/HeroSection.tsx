import React from 'react';
import { motion } from 'framer-motion';
import { ArrowRight, Play, Sparkles, ShieldCheck, Zap } from 'lucide-react';
import { Button } from '../components/common/Button';
import { HeroDashboardMockup } from '../components/hero/HeroDashboardMockup';

export const HeroSection: React.FC = () => {
  const scrollToContact = () => {
    const el = document.getElementById('contact-form');
    if (el) {
      el.scrollIntoView({ behavior: 'smooth' });
    }
  };

  const scrollToDemo = () => {
    const el = document.getElementById('features-section');
    if (el) {
      el.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <section className="relative pt-24 pb-16 md:pt-40 md:pb-28 overflow-hidden transition-colors">
      {/* Background radial gradients */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[1000px] h-[550px] bg-red-500/10 dark:bg-red-500/15 rounded-full blur-[160px] pointer-events-none -z-10" />
      <div className="absolute top-1/4 -left-40 w-96 h-96 bg-amber-500/10 rounded-full blur-[140px] pointer-events-none -z-10" />

      {/* Grid Pattern overlay */}
      <div className="absolute inset-0 bg-[linear-gradient(to_right,#8080800a_1px,transparent_1px),linear-gradient(to_bottom,#8080800a_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_0%,#000_70%,transparent_100%)] pointer-events-none -z-10" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-4xl mx-auto">
          {/* Badge */}
          <motion.div
            initial={{ opacity: 0, y: -15 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className="inline-flex items-center gap-2 px-3 sm:px-4 py-1.5 rounded-full glass-panel border border-red-500/30 bg-red-500/10 text-red-600 dark:text-red-400 text-[11px] sm:text-xs font-bold mb-6 shadow-sm max-w-full"
          >
            <Sparkles className="w-3.5 h-3.5 shrink-0 animate-spin" style={{ animationDuration: '6s' }} />
            <span>ZAVERO FAST • Restoran Avtomatlashtirish Ekotizimi</span>
          </motion.div>

          {/* Main Headline */}
          <motion.h1
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="text-3xl sm:text-5xl md:text-6xl lg:text-7xl font-black tracking-tight text-gray-900 dark:text-white leading-[1.15] mb-4 sm:mb-6"
          >
            Cafe va restoraningizni{' '}
            <span className="text-gradient block sm:inline">bitta tizimda</span> boshqaring.
          </motion.h1>

          {/* Subtitle */}
          <motion.p
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="text-sm sm:text-lg md:text-xl text-gray-600 dark:text-gray-300 mb-8 sm:mb-10 max-w-3xl mx-auto font-normal leading-relaxed"
          >
            Zavero — buyurtmalar, xodimlar, stollar, mijozlar va biznesingizni boshqarish uchun zamonaviy avtomatlashtirish tizimi.
          </motion.p>

          {/* CTA Buttons */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.3 }}
            className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-8"
          >
            <Button
              variant="primary"
              size="lg"
              onClick={scrollToContact}
              rightIcon={<ArrowRight className="w-4 h-4" />}
              className="w-full sm:w-auto px-8 py-4 text-base"
            >
              Zavero bilan boshlash
            </Button>

            <Button
              variant="secondary"
              size="lg"
              onClick={scrollToDemo}
              leftIcon={<Play className="w-4 h-4 text-red-600 fill-red-600" />}
              className="w-full sm:w-auto px-8 py-4 text-base"
            >
              Demo ko'rish
            </Button>
          </motion.div>

          {/* Trust badges */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.8, delay: 0.4 }}
            className="flex flex-wrap items-center justify-center gap-4 sm:gap-10 text-xs text-gray-600 dark:text-gray-400 font-medium"
          >
            <span className="flex items-center gap-1.5">
              <Zap className="w-3.5 h-3.5 text-amber-500" /> Tezkor o'rnatish (1 kunda)
            </span>
            <span className="flex items-center gap-1.5">
              <ShieldCheck className="w-3.5 h-3.5 text-red-500" /> 3 kunlik bepul sinov
            </span>
            <span className="flex items-center gap-1.5">
              <Sparkles className="w-3.5 h-3.5 text-cyan-500" /> 24/7 texnik yordam
            </span>
          </motion.div>
        </div>

        {/* Hero Mockup */}
        <motion.div
          initial={{ opacity: 0, y: 40 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.45, ease: [0.16, 1, 0.3, 1] }}
        >
          <HeroDashboardMockup />
        </motion.div>
      </div>
    </section>
  );
};
