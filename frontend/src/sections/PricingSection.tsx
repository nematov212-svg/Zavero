import React from 'react';
import { motion } from 'framer-motion';
import { Check, Sparkles, Zap, Flame, Infinity as InfinityIcon, ArrowRight } from 'lucide-react';
import { Button } from '../components/common/Button';

interface PricingSectionProps {
  id?: string;
  showTitle?: boolean;
}

export const PricingSection: React.FC<PricingSectionProps> = ({
  id = 'pricing',
  showTitle = true,
}) => {
  const scrollToContact = (planName: string) => {
    const el = document.getElementById('contact-form') || document.getElementById('boglanish');
    if (el) {
      el.scrollIntoView({ behavior: 'smooth' });
      // Pre-fill or notify message area if element exists
      const msgInput = document.querySelector('textarea[name="message"]') as HTMLTextAreaElement | null;
      if (msgInput) {
        msgInput.value = `Salom! Men "${planName}" tarifi bo'yicha ulanmoqchiman.`;
      }
    }
  };

  const plans = [
    {
      name: '1 Oylik Tarif',
      badge: 'Boshlang\'ich',
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
        'QR-menyu bilan ishlash',
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
      description: 'O\'rta va katta restoranlar uchun eng katta chegirmali tarif',
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
    <section id={id} className="relative py-24 bg-white dark:bg-[#070A12] border-t border-gray-200 dark:border-white/[0.06] transition-colors">
      {/* Background radial glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[700px] h-[400px] bg-red-600/5 blur-[140px] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        {showTitle && (
          <div className="text-center max-w-3xl mx-auto mb-16">
            <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-red-500/10 border border-red-500/25 text-red-600 dark:text-red-400 text-xs font-bold mb-4">
              <Zap className="w-3.5 h-3.5" />
              <span>Ilovani Ishlatish Tariflari</span>
            </div>
            <h2 className="text-3xl sm:text-5xl font-black text-gray-900 dark:text-white tracking-tight mb-4">
              Restoraningiz uchun shaffof va qulay narxlar
            </h2>
            <p className="text-gray-600 dark:text-gray-400 text-base sm:text-lg leading-relaxed">
              Hech qanday yashirin to'lovlar yo'q. Istalgan qulay tarifni tanlang yoki bir umrga cheksiz litsenziyani qo'lga kiriting!
            </p>
          </div>
        )}

        {/* 4 Cards Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 items-stretch">
          {plans.map((plan, index) => (
            <motion.div
              key={plan.name}
              initial={{ opacity: 0, y: 25 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.45, delay: index * 0.08 }}
              className={`relative glass-card rounded-2xl sm:rounded-3xl p-5 sm:p-7 border flex flex-col justify-between transition-all duration-300 hover:shadow-2xl hover:-translate-y-1 ${plan.popular
                  ? 'border-red-500/70 bg-gradient-to-b from-red-500/[0.06] to-transparent dark:bg-[#101524] shadow-xl shadow-red-500/10'
                  : 'border-gray-200 dark:border-white/10 hover:border-gray-300 dark:hover:border-white/20'
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

                <h3 className="text-xl font-black text-gray-900 dark:text-white mb-1.5">{plan.name}</h3>
                <p className="text-xs text-gray-500 dark:text-gray-400 mb-5 min-h-[32px] leading-relaxed">
                  {plan.description}
                </p>

                <div className="pb-5 mb-5 border-b border-gray-200 dark:border-white/[0.08]">
                  {plan.originalPrice && (
                    <div className="text-xs text-gray-400 line-through font-mono">
                      {plan.originalPrice} so'm
                    </div>
                  )}

                  <div className="flex items-baseline gap-1 mt-0.5">
                    <span className="text-3xl sm:text-4xl font-black text-gray-900 dark:text-white font-mono tracking-tight">
                      {plan.price}
                    </span>
                  </div>
                  <span className="text-xs text-gray-500 dark:text-gray-400 font-semibold block mt-1">
                    {plan.period}
                  </span>

                  {plan.discountText && (
                    <span className="inline-block mt-2.5 text-[11px] font-bold px-2.5 py-0.5 rounded-lg bg-red-500/10 text-red-600 dark:text-red-400 border border-red-500/25">
                      {plan.discountText}
                    </span>
                  )}
                </div>

                <ul className="space-y-2.5 mb-6 text-xs text-gray-700 dark:text-gray-300">
                  {plan.features.map((feat, i) => (
                    <li key={i} className="flex items-start gap-2">
                      <span className="w-4 h-4 rounded-full bg-red-500/15 text-red-600 dark:text-red-400 flex items-center justify-center shrink-0 mt-0.5">
                        <Check className="w-2.5 h-2.5 stroke-[3]" />
                      </span>
                      <span className="leading-tight">{feat}</span>
                    </li>
                  ))}
                </ul>
              </div>

              <Button
                variant={plan.popular ? 'primary' : 'secondary'}
                size="md"
                onClick={() => scrollToContact(plan.name)}
                className="w-full justify-center group font-bold cursor-pointer"
              >
                <span>Tanlash va ulanish</span>
                <ArrowRight className="w-4 h-4 ml-1 group-hover:translate-x-1 transition-transform" />
              </Button>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
};
