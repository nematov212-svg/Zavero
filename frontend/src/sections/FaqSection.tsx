import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronDown, HelpCircle } from 'lucide-react';

const faqs = [
  {
    q: 'Zavero tizimini o\'rnatish qancha vaqt oladi?',
    a: 'Odatda tizimni o\'rnatish va printerlar bilan integratsiya qilish atigi 1 kun davom etadi. Bizning texnik mutaxassislarimiz menyungizni kiritish va xodimlaringizni o\'qitishda to\'liq yordam berishadi.',
  },
  {
    q: 'Internet uzilib qolsa tizim ishlayveradimi?',
    a: 'Ha! Zavero Flutter offline-first arxitekturasida yaratilgan. Internet o\'chgan taqdirda ham ofitsiantlar buyurtma olishda, oshxona chek chiqarishda va kassa ishlashda davom etadi. Internet paydo bo\'lishi bilan barcha ma\'lumotlar bulutga sinxronlanadi.',
  },
  {
    q: 'Mavjud uskunalarimizdan (planshet, printer, kassa) foydalana olamizmi?',
    a: 'Ha, Zavero har qanday Android/iOS planshet, smartfon va ESC/POS (Wi-Fi, Bluetooth, USB) chek printerlari bilan mos keladi. Yangi qimmat server yoki uskunalar sotib olishingiz shart emas.',
  },
  {
    q: 'O\'zbekiston to\'lov tizimlari (Click, Payme, Uzum) qo\'llab-quvvatlanadimi?',
    a: 'Albatta! Tizimga Click, Payme, Uzum va bank terminallari to\'liq integratsiya qilingan bo\'lib, dinamik QR orqali to\'lovlarni bir zumda tasdiqlash imkoniyati mavjud.',
  },
  {
    q: 'Bir nechta filiallarimiz bo\'lsa qanday boshqaramiz?',
    a: 'Zavero Director Panel orqali barcha filiallar statistikasi, xodimlar KPIsi, ombor qoldig\'i va savdoni yagona ekranda kuzatishingiz mumkin.',
  },
];

export const FaqSection: React.FC = () => {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <section className="relative py-24 bg-white dark:bg-[#090C16] border-t border-gray-200 dark:border-white/[0.06] overflow-hidden transition-colors">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="text-center mb-16">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-xs font-semibold mb-4">
            <HelpCircle className="w-3.5 h-3.5" />
            <span>Savol-Javoblar</span>
          </div>

          <h2 className="text-3xl sm:text-5xl font-extrabold text-gray-900 dark:text-white tracking-tight mb-4">
            Ko'p beriladigan savollar
          </h2>
          <p className="text-gray-600 dark:text-gray-400 text-base">
            Zavero haqida eng ko'p so'raladigan savollarga aniq javoblar.
          </p>
        </div>

        <div className="space-y-4">
          {faqs.map((faq, index) => {
            const isOpen = openIndex === index;
            return (
              <div
                key={index}
                className="glass-card rounded-2xl border border-gray-200 dark:border-white/10 overflow-hidden transition-all"
              >
                <button
                  onClick={() => setOpenIndex(isOpen ? null : index)}
                  className="w-full p-6 text-left flex items-center justify-between gap-4 focus:outline-none cursor-pointer"
                >
                  <span className="text-base sm:text-lg font-bold text-gray-900 dark:text-white">
                    {faq.q}
                  </span>
                  <div
                    className={`w-8 h-8 rounded-full bg-gray-100 dark:bg-white/[0.05] border border-gray-200 dark:border-white/10 flex items-center justify-center text-gray-500 dark:text-gray-300 shrink-0 transition-transform duration-300 ${
                      isOpen ? 'rotate-180 text-red-600 dark:text-red-400 border-red-500/40' : ''
                    }`}
                  >
                    <ChevronDown className="w-4 h-4" />
                  </div>
                </button>

                <AnimatePresence>
                  {isOpen && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: 'auto', opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.3 }}
                    >
                      <div className="px-6 pb-6 pt-1 text-sm text-gray-600 dark:text-gray-300 leading-relaxed border-t border-gray-200 dark:border-white/[0.04]">
                        {faq.a}
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
};
