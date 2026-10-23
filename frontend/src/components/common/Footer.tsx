import React from 'react';
import { Link } from 'react-router-dom';
import { Logo } from './Logo';
import { Phone, Mail, MapPin, Send, ShieldCheck, Heart, Sparkles } from 'lucide-react';

export const Footer: React.FC = () => {
  return (
    <footer className="relative bg-white dark:bg-[#06080D] border-t border-gray-200 dark:border-white/[0.08] overflow-hidden pt-16 pb-12 transition-colors">
      {/* Background ambient lighting */}
      <div className="absolute bottom-0 left-1/4 w-96 h-96 bg-red-500/5 rounded-full blur-[120px] pointer-events-none" />
      <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-rose-500/5 rounded-full blur-[120px] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-10 pb-12 border-b border-gray-200 dark:border-white/[0.08]">
          {/* Brand info */}
          <div className="lg:col-span-2 space-y-4">
            <Logo size="lg" />
            <p className="text-gray-600 dark:text-gray-400 text-sm leading-relaxed max-w-sm">
              Zavero — O'zbekistondagi zamonaviy cafe va restoranlar uchun to'liq avtomatlashtirish ekotizimi. Buyurtmalar, kassa, stollar, xodimlar va mijozlarni yagona smart platformada birlashtiring.
            </p>
            <div className="flex items-center gap-2 pt-2">
              <span className="flex h-2.5 w-2.5 relative">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500"></span>
              </span>
              <span className="text-xs text-gray-500 dark:text-gray-400">Barcha serverlar va API barqaror ishlamoqda (99.98%)</span>
            </div>
          </div>

          {/* Mahsulot */}
          <div>
            <h4 className="text-gray-900 dark:text-white font-bold text-sm mb-4 tracking-wider uppercase">Mahsulot</h4>
            <ul className="space-y-2.5 text-sm">
              <li>
                <Link to="/features" className="text-gray-600 dark:text-gray-400 hover:text-red-500 transition-colors">
                  Imkoniyatlar
                </Link>
              </li>
              <li>
                <a
                  href={import.meta.env.VITE_APP_URL || "https://app.zavero.uz"}
                  target="_blank"
                  rel="noreferrer"
                  className="text-red-600 dark:text-red-400 hover:underline font-semibold inline-flex items-center gap-1.5 transition-colors"
                >
                  <Sparkles className="w-3.5 h-3.5" />
                  Zavero POS Web Ilova
                </a>
              </li>
              <li>
                <Link to="/features#waiter" className="text-gray-600 dark:text-gray-400 hover:text-red-500 transition-colors">
                  Ofitsiant Flutter ilovasi
                </Link>
              </li>
              <li>
                <Link to="/features#kitchen" className="text-gray-600 dark:text-gray-400 hover:text-red-500 transition-colors">
                  Oshxona ekrani (KDS)
                </Link>
              </li>
              <li>
                <Link to="/pricing" className="text-gray-600 dark:text-gray-400 hover:text-red-500 transition-colors">
                  Tariflar
                </Link>
              </li>
            </ul>
          </div>

          {/* Kompaniya */}
          <div>
            <h4 className="text-gray-900 dark:text-white font-bold text-sm mb-4 tracking-wider uppercase">Kompaniya</h4>
            <ul className="space-y-2.5 text-sm">
              <li>
                <Link to="/about" className="text-gray-600 dark:text-gray-400 hover:text-red-500 transition-colors">
                  Biz haqimizda
                </Link>
              </li>
              <li>
                <Link to="/contact" className="text-gray-600 dark:text-gray-400 hover:text-red-500 transition-colors">
                  Bog'lanish
                </Link>
              </li>
              <li>
                <a
                  href="https://t.me/Zaverozakas_bot"
                  target="_blank"
                  rel="noreferrer"
                  className="text-red-600 dark:text-red-400 font-semibold inline-flex items-center gap-1.5 hover:underline transition-colors"
                >
                  <Send className="w-3.5 h-3.5" />
                  Telegram Bot (@Zaverozakas_bot)
                </a>
              </li>
            </ul>
          </div>

          {/* Aloqa */}
          <div>
            <h4 className="text-gray-900 dark:text-white font-bold text-sm mb-4 tracking-wider uppercase">Aloqa</h4>
            <ul className="space-y-3 text-sm text-gray-600 dark:text-gray-400">
              <li className="flex items-center gap-2.5">
                <Phone className="w-4 h-4 text-red-500 shrink-0" />
                <a href="tel:+998507230475" className="hover:text-red-500 transition-colors font-mono">
                  +998 (50) 723-04-75
                </a>
              </li>
              <li className="flex items-center gap-2.5">
                <Send className="w-4 h-4 text-red-500 shrink-0" />
                <a href="https://t.me/zavero_uz" target="_blank" rel="noreferrer" className="hover:text-red-500 transition-colors">
                  @zavero_uz
                </a>
              </li>
              <li className="flex items-center gap-2.5">
                <Mail className="w-4 h-4 text-red-500 shrink-0" />
                <a href="mailto:mirzobek@zavero.uz" className="hover:text-red-500 transition-colors">
                  mirzobek@zavero.uz
                </a>
              </li>
              <li className="flex items-start gap-2.5">
                <MapPin className="w-4 h-4 text-red-500 shrink-0 mt-0.5" />
                <span>Samarqand viloyati Urgut tumani ispanza registon 14 uy</span>
              </li>
            </ul>
          </div>
        </div>

        {/* Bottom bar */}
        <div className="pt-8 flex flex-col sm:flex-row items-center justify-between text-xs text-gray-500 dark:text-gray-400 gap-4">
          <p>© {new Date().getFullYear()} ZAVERO Technologies Inc. Barcha huquqlar himoyalangan.</p>
          <div className="flex items-center gap-6">
            <span className="hover:text-gray-700 dark:hover:text-gray-300 transition-colors cursor-pointer">Maxfiylik siyosati</span>
            <span className="hover:text-gray-700 dark:hover:text-gray-300 transition-colors cursor-pointer">Foydalanish shartlari</span>
            <span className="flex items-center gap-1 text-gray-500">
              Made with <Heart className="w-3 h-3 text-red-500 fill-current" /> in Urgut
            </span>
          </div>
        </div>
      </div>
    </footer>
  );
};
