import React from 'react';
import { Phone, Mail, MapPin, Send, MessageCircle } from 'lucide-react';
import { LeadFormSection } from '../../sections/LeadFormSection';

export const ContactPage: React.FC = () => {
  return (
    <div className="pt-28 pb-20">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mb-12">
        <div className="text-center max-w-3xl mx-auto mb-16">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-xs font-semibold mb-4">
            <MessageCircle className="w-3.5 h-3.5" />
            <span>To'g'ridan-to'g'ri Aloqa</span>
          </div>
          <h1 className="text-4xl sm:text-6xl font-black text-gray-900 dark:text-white tracking-tight mb-6">
            Biz bilan bog'laning
          </h1>
          <p className="text-gray-600 dark:text-gray-300 text-lg leading-relaxed">
            Savollaringiz bormi yoki restoraningiz uchun mos tarifni tanlashda yordam kerakmi? Bizning mutaxassislarimiz har doim sizga ko'maklashishga tayyor.
          </p>
        </div>

        {/* Contact Info Cards Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-16">
          <div className="glass-card p-6 sm:p-8 rounded-3xl border border-gray-200 dark:border-white/10 flex flex-col justify-between">
            <div>
              <div className="w-12 h-12 rounded-2xl bg-red-500/10 border border-red-500/30 flex items-center justify-center text-red-600 dark:text-red-400 mb-4">
                <Phone className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-1">Telefon orqali</h3>
              <p className="text-xs text-gray-500 dark:text-gray-400 mb-4">Har kuni 09:00 dan 21:00 gacha qo'ng'iroqlarni qabul qilamiz.</p>
            </div>
            <a
              href="tel:+998507230475"
              className="text-base font-bold text-red-600 dark:text-red-400 hover:underline transition-colors font-mono"
            >
              +998 (50) 723-04-75
            </a>
          </div>

          <div className="glass-card p-6 sm:p-8 rounded-3xl border border-gray-200 dark:border-white/10 flex flex-col justify-between">
            <div>
              <div className="w-12 h-12 rounded-2xl bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-cyan-600 dark:text-cyan-400 mb-4">
                <Send className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-1">Telegram orqali</h3>
              <p className="text-xs text-gray-500 dark:text-gray-400 mb-4">Tezkor savol-javob va demo taqdimotni belgilash uchun.</p>
            </div>
            <a
              href="https://t.me/zavero_uz"
              target="_blank"
              rel="noreferrer"
              className="text-base font-bold text-cyan-600 dark:text-cyan-400 hover:underline transition-colors"
            >
              @zavero_uz →
            </a>
          </div>

          <div className="glass-card p-6 sm:p-8 rounded-3xl border border-gray-200 dark:border-white/10 flex flex-col justify-between">
            <div>
              <div className="w-12 h-12 rounded-2xl bg-indigo-500/10 border border-indigo-500/30 flex items-center justify-center text-indigo-600 dark:text-indigo-400 mb-4">
                <MapPin className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-1">Bosh ofisimiz</h3>
              <p className="text-xs text-gray-500 dark:text-gray-400 mb-4">Mehmon bo'ling, kofe ichib tizimni jonli sinab ko'ramiz.</p>
            </div>
            <p className="text-sm font-semibold text-gray-900 dark:text-white">
              Samarqand viloyati Urgut tumani ispanza registon 14 uy
            </p>
          </div>
        </div>
      </div>

      <LeadFormSection />
    </div>
  );
};
