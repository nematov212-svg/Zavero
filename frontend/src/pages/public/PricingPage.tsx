import React from 'react';
import { motion } from 'framer-motion';
import { Check, Sparkles, Zap, Shield, ArrowRight, Flame, Infinity as InfinityIcon } from 'lucide-react';
import { Button } from '../../components/common/Button';
import { LeadFormSection } from '../../sections/LeadFormSection';
import { FaqSection } from '../../sections/FaqSection';

export const PricingPage: React.FC = () => {
  const scrollToContact = () => {
    const el = document.getElementById('contact-form');
    if (el) el.scrollIntoView({ behavior: 'smooth' });
  };

  const plans = [
    {
      name: '1 Oylik Tarif',
      badge: 'Oylik',
      badgeColor: 'bg-gray-500/10 text-gray-700 dark:text-gray-300 border-gray-300 dark:border-white/10',
      description: 'Kichik kofe va qahvaxonalar, fast-food shoxobchalari uchun',
      price: '200,000',
      period: 'so\'m / oy',
      originalPrice: null,
      discountText: null,
      popular: false,
      features: [
        '1 ta filial',
        'Cheksiz ofitsiant va kassa qurilmalari',
        'Stollar va zallar xaritasi',
        'Chek va pre-chek chiqarish',
        'Qr-menu bilan ishlash ',
        'Kunlik savdo va tushum hisoboti',
        'Telegram bot orqali bildirishnomalar',
        '24/7 texnik yordam',
      ],
    },
    {
      name: '3 Oylik Tarif',
      badge: 'Tejamkor',
      badgeColor: 'bg-blue-500/10 text-blue-600 dark:text-blue-400 border-blue-500/30',
      description: 'Qulay narxda 3 oylik to\'liq avtomatlashtirish paketi',
      price: '550,000',
      period: 'so\'m / 3 oy',
      originalPrice: '600,000',
      discountText: '50,000 so\'m chegirma',
      popular: false,
      features: [
        '1 ta filial',
        'Cheksiz ofitsiant va kassa qurilmalari',
        'Oshxona ekrani (KDS) moduli',
        'Xodimlar KPI va davomat nazorati',
        'Chek chiqarish va QR menyu',
        'Click / Payme to\'lov integratsiyasi',
        '50,000 so\'m tejaladi',
      ],
    },
    {
      name: '9 Oylik Tarif',
      badge: 'Eng Ommabop 🔥',
      badgeColor: 'bg-red-500/15 text-red-600 dark:text-red-400 border-red-500/40',
      description: 'O\'rta va katta restoranlar uchun eng manfaatli chegirmali tarif',
      price: '1,500,000',
      period: 'so\'m / 9 oy',
      originalPrice: '1,800,000',
      discountText: '300,000 so\'m KATTA CHEGIRMA',
      popular: true,
      features: [
        'To\'liq Zavero ekotizimi',
        'Cheksiz stollar, ofitsiantlar va kassa',
        'Oshxona ekrani (KDS) + Bar integratsiyasi',
        'Mijozlar sodiqlik dasturi (Keshbek CRM)',
        'Click / Payme / Uzum to\'lov tizimlari',
        'Ombor hisobi va kalkulyatsiya',
        '300,000 so\'m to\'liq tejash',
        'Shaxsiy texnik mutaxassis xizmati',
      ],
    },
    {
      name: 'Cheksiz Tarif (Umrbod)',
      badge: 'Lifetime / Cheksiz',
      badgeColor: 'bg-amber-500/15 text-amber-600 dark:text-amber-400 border-amber-500/40',
      description: 'Bir marta to\'laysiz va oylik to\'lovlarsiz umrbod foydalanasiz',
      price: '2,200,000',
      period: 'so\'m (Bir martalik to\'lov)',
      originalPrice: null,
      discountText: 'Oylik to\'lov yo\'q • Umrbod litsenziya',
      popular: false,
      features: [
        'Bir umrga cheksiz litsenziya',
        'Oylik yoki yillik to\'lovlarsiz',
        'Barcha kelajakdagi yangilanishlar bepul',
        'Cheksiz qurilmalar va ofitsiantlar',
        'Barcha to\'lov tizimlari (Click, Payme, Kartalar)',
        'VIP darajadagi 24/7 ustuvor texnik servis',
        'Joyiga chiqqan holda bepul o\'rnatish',
      ],
    },
  ];

  return (
    <div className="pt-28 pb-20">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center mb-16">
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-xs font-bold mb-4">
          <Zap className="w-3.5 h-3.5" />
          <span>Ilovani Ishlatish Shaffof Narxlari</span>
        </div>
        <h1 className="text-4xl sm:text-6xl font-black text-gray-900 dark:text-white tracking-tight mb-5">
          Restoraningiz uchun qulay tariflar
        </h1>
        <p className="text-gray-600 dark:text-gray-300 text-base sm:text-lg max-w-2xl mx-auto leading-relaxed">
          Hech qanday yashirin xarajatlar yo'q. Qancha muddatga xarid qilsangiz, shuncha ko'proq tejang!
        </p>
      </div>

      {/* 4 Pricing Cards Grid */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mb-24">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 items-stretch">
          {plans.map((plan, index) => (
            <motion.div
              key={plan.name}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.4, delay: index * 0.08 }}
              className={`relative glass-card rounded-3xl p-6 sm:p-7 border flex flex-col justify-between ${plan.popular
                ? 'border-red-500/60 bg-red-500/[0.03] dark:bg-[#12172A] shadow-xl shadow-red-500/10'
                : 'border-gray-200 dark:border-white/10'
                }`}
            >
              {plan.popular && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-3.5 py-1 rounded-full bg-red-600 text-white font-extrabold text-[11px] uppercase tracking-wider shadow-lg flex items-center gap-1">
                  <Flame className="w-3 h-3 fill-white" />
                  Eng Ommabop
                </div>
              )}

              <div>
                <div className="flex items-center justify-between mb-3">
                  <span className={`px-2.5 py-1 rounded-full text-[11px] font-bold border ${plan.badgeColor}`}>
                    {plan.badge}
                  </span>
                </div>

                <h3 className="text-xl font-black text-gray-900 dark:text-white mb-1">{plan.name}</h3>
                <p className="text-xs text-gray-500 dark:text-gray-400 mb-5 min-h-[32px]">{plan.description}</p>

                <div className="pb-5 mb-5 border-b border-gray-200 dark:border-white/[0.08]">
                  {plan.originalPrice && (
                    <div className="text-xs text-gray-400 line-through font-mono">
                      {plan.originalPrice} so'm
                    </div>
                  )}

                  <div className="flex items-baseline gap-1 mt-0.5">
                    <span className="text-3xl font-black text-gray-900 dark:text-white font-mono">
                      {plan.price}
                    </span>
                  </div>
                  <span className="text-xs text-gray-500 dark:text-gray-400 font-medium block mt-0.5">
                    {plan.period}
                  </span>

                  {plan.discountText && (
                    <span className="inline-block mt-2 text-[11px] font-bold px-2 py-0.5 rounded-md bg-red-500/10 text-red-600 dark:text-red-400 border border-red-500/20">
                      {plan.discountText}
                    </span>
                  )}
                </div>

                <ul className="space-y-2.5 mb-6 text-xs text-gray-700 dark:text-gray-300">
                  {plan.features.map((feat, i) => (
                    <li key={i} className="flex items-center gap-2">
                      <span className="w-4 h-4 rounded-full bg-red-500/20 text-red-600 dark:text-red-400 flex items-center justify-center shrink-0">
                        <Check className="w-2.5 h-2.5" />
                      </span>
                      <span>{feat}</span>
                    </li>
                  ))}
                </ul>
              </div>

              <Button
                variant={plan.popular ? 'primary' : 'secondary'}
                size="md"
                onClick={scrollToContact}
                className="w-full justify-center"
              >
                Tanlash va ulanish
              </Button>
            </motion.div>
          ))}
        </div>
      </div>

      <LeadFormSection />
      <FaqSection />
    </div>
  );
};
