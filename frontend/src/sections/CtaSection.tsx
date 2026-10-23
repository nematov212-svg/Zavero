import React from 'react';
import { ArrowRight, PhoneCall, Sparkles } from 'lucide-react';
import { Button } from '../components/common/Button';

export const CtaSection: React.FC = () => {
  const scrollToContact = () => {
    const el = document.getElementById('contact-form') || document.getElementById('boglanish');
    if (el) el.scrollIntoView({ behavior: 'smooth' });
  };

  return (
    <section className="relative py-24 bg-white dark:bg-[#080A10] overflow-hidden transition-colors">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="relative rounded-3xl p-8 sm:p-14 overflow-hidden border border-red-500/30 bg-gradient-to-b from-red-500/[0.04] to-red-500/[0.08] dark:from-[#0E1528] dark:to-[#0A0D18] shadow-2xl">
          {/* Ambient Lighting inside card */}
          <div className="absolute top-0 right-0 w-96 h-96 bg-red-500/10 rounded-full blur-[100px] pointer-events-none" />
          <div className="absolute bottom-0 left-0 w-96 h-96 bg-rose-500/10 rounded-full blur-[100px] pointer-events-none" />

          <div className="relative z-10 text-center max-w-3xl mx-auto space-y-6">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-red-500/15 border border-red-500/30 text-red-600 dark:text-red-400 text-xs font-semibold">
              <Sparkles className="w-3.5 h-3.5" />
              <span>3 kunlik bepul sinov davri</span>
            </div>


            <h2 className="text-3xl sm:text-5xl font-black text-gray-900 dark:text-white tracking-tight leading-tight">
              Restoraningizni bugunoq kelajak texnologiyasi bilan jihozlang
            </h2>

            <p className="text-gray-600 dark:text-gray-300 text-base sm:text-lg leading-relaxed max-w-2xl mx-auto">
              Zavero tizimini o'rnatish uchun hech qanday murakkab serverlar shart emas. Mutaxassislarimiz barcha jarayonni o'zlari amalga oshirib berishadi.
            </p>

            <div className="flex flex-col sm:flex-row items-center justify-center gap-4 pt-4">
              <Button
                variant="primary"
                size="lg"
                onClick={scrollToContact}
                rightIcon={<ArrowRight className="w-4 h-4" />}
                className="w-full sm:w-auto px-8 py-4 text-base font-bold shadow-lg shadow-red-500/20"
              >
                Bepul demo olish
              </Button>

              <a href="tel:+998507230475" className="w-full sm:w-auto">
                <Button
                  variant="secondary"
                  size="lg"
                  leftIcon={<PhoneCall className="w-4 h-4 text-red-600 dark:text-red-400" />}
                  className="w-full justify-center px-8 py-4 text-base font-bold"
                >
                  +998 (50) 723-04-75
                </Button>
              </a>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};
