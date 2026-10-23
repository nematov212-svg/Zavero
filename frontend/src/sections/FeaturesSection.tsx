import React from 'react';
import { motion } from 'framer-motion';
import {
  Receipt,
  LayoutGrid,
  Users,
  HeartHandshake,
  BarChart3,
  Printer,
  QrCode,
  CreditCard,
  Network,
  Check,
  Sparkles,
} from 'lucide-react';

interface FeatureCardProps {
  icon: React.ReactNode;
  emoji: string;
  title: string;
  description: string;
  highlights: string[];
  gradient: string;
}

const featuresList: FeatureCardProps[] = [
  {
    icon: <Receipt className="w-6 h-6 text-emerald-400" />,
    emoji: '🧾',
    title: 'Buyurtmalar boshqaruvi',
    description: 'Ofitsiant planshetidan oshxona va bar printerlariga buyurtmalarni 0.2 soniyada yetkazish. Hech bir buyurtma adashmaydi yoki kechikmaydi.',
    highlights: ['Modifikatorlar & istaklar', 'Kurslar bo\'yicha uzatish', 'Real vaqtda oshxona ekrani (KDS)'],
    gradient: 'from-emerald-500/20 via-transparent to-transparent',
  },
  {
    icon: <LayoutGrid className="w-6 h-6 text-cyan-400" />,
    emoji: '🪑',
    title: 'Stol va zallar boshqaruvi',
    description: 'Restoraningiz xaritasini 2D/3D interaktiv shaklda sozlang. Zallarni, terrasa va VIP xonalarni bandligi, vaqti va joriy hisobini ko\'ring.',
    highlights: ['Stollarni birlashtirish & bo\'lish', 'Zaxira (Bron) tizimi', 'Xizmat ko\'rsatish taymeri'],
    gradient: 'from-cyan-500/20 via-transparent to-transparent',
  },
  {
    icon: <Users className="w-6 h-6 text-indigo-400" />,
    emoji: '👨‍💼',
    title: 'Xodimlar nazorati & KPI',
    description: 'Har bir ofitsiant, oshpaz va kassirning shaxsiy statistikasi. Kim qancha savdo qildi, qancha chek yopdi, xizmat ko\'rsatish tezligi.',
    highlights: ['Shaxsiy PIN-kod & kirish huquqlari', 'Avtomatik choypuli hisobi', 'Davomat & smena nazorati'],
    gradient: 'from-indigo-500/20 via-transparent to-transparent',
  },
  {
    icon: <HeartHandshake className="w-6 h-6 text-pink-400" />,
    emoji: '👥',
    title: 'Mijozlar & Sodiqlik (CRM)',
    description: 'Mijozlarning telefon raqami, tashriflar soni, sevimli taomlari va sarflagan pullari bazasi. Keshbek va shaxsiy chegirmalar tizimi.',
    highlights: ['SMS xabarnomalar', 'Keshbek tizimi (1-10%)', 'Tug\'ilgan kun avto-tabriklari'],
    gradient: 'from-pink-500/20 via-transparent to-transparent',
  },
  {
    icon: <BarChart3 className="w-6 h-6 text-amber-400" />,
    emoji: '📊',
    title: 'Chuqur tahlil & Statistika',
    description: 'Kunlik, oylik va yillik savdo hisobotlari. Eng ko\'p sotilgan (Top) taomlar, xom-ashyo qoldig\'i va kassa kirim-chiqim nazorati.',
    highlights: ['Foyda & rentabellik tahlili', 'Toshqin (Peak) soatlar statistikasi', 'Telegram botga kunlik hisobot'],
    gradient: 'from-amber-500/20 via-transparent to-transparent',
  },
  {
    icon: <Printer className="w-6 h-6 text-teal-400" />,
    emoji: '🖨',
    title: 'Chek va pre-chek chiqarish',
    description: 'Bluetooth, Wi-Fi, Ethernet va USB chek printerlariga to\'liq integratsiya. Fiskal cheklar va oshxona slayderlari bir zumda chop etiladi.',
    highlights: ['Barcha ESC/POS printerlar', 'QR kodli fiskal cheklar', 'Maxsus logotipli chek shabloni'],
    gradient: 'from-teal-500/20 via-transparent to-transparent',
  },
  {
    icon: <QrCode className="w-6 h-6 text-violet-400" />,
    emoji: '📱',
    title: 'Elektron QR Menu',
    description: 'Mijozlar smartfoni orqali stol ustidagi QR kodni skanerlab, taomlar rasmlari, tarkibi va narxlarini ko\'radi. Xohlasa to\'g\'ridan-to\'g\'ri buyurtma beradi.',
    highlights: ['Fotosuratlar & videoli menyu', 'Bir zumda narx yangilash', 'Stop-list (tugagan taomlar)'],
    gradient: 'from-violet-500/20 via-transparent to-transparent',
  },
  {
    icon: <CreditCard className="w-6 h-6 text-emerald-400" />,
    emoji: '💰',
    title: 'To\'lovlar & Milliy tizimlar',
    description: 'Click, Payme, Uzum Bank va xalqaro Visa/Mastercard kartalari orqali bir zumda to\'lov qabul qilish. Hisobni do\'stlar o\'rtasida bo\'lib to\'lash.',
    highlights: ['Click / Payme QR to\'lov', 'Karta & naqd aralash to\'lov', 'Avtomatik kassa solishtiruvi'],
    gradient: 'from-emerald-500/20 via-transparent to-transparent',
  },
  {
    icon: <Network className="w-6 h-6 text-blue-400" />,
    emoji: '🏪',
    title: 'Bir nechta filiallar boshqaruvi',
    description: 'Agar sizda 2 ta yoki 50 ta filial bo\'lsa ham, barchasini yagona Zavero Director Panel orqali masofadan, real vaqtda boshqaring.',
    highlights: ['Umumiy ombor & mahsulot ko\'chirish', 'Filiallar o\'rtasida reyting', 'Yagona menyu sinxronizatsiyasi'],
    gradient: 'from-blue-500/20 via-transparent to-transparent',
  },
];

export const FeaturesSection: React.FC = () => {
  return (
    <section id="features-section" className="relative py-28 bg-white dark:bg-[#090C16] border-t border-gray-200 dark:border-white/[0.06] overflow-hidden transition-colors">
      {/* Background ambient lighting */}
      <div className="absolute top-1/4 right-0 w-96 h-96 bg-red-500/5 rounded-full blur-[140px] pointer-events-none" />
      <div className="absolute bottom-1/4 left-0 w-96 h-96 bg-rose-500/5 rounded-full blur-[140px] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="text-center max-w-3xl mx-auto mb-20">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-xs font-semibold mb-4">
            <Sparkles className="w-3.5 h-3.5" />
            <span>To'liq Funksional Ekotizim</span>
          </div>

          <h2 className="text-3xl sm:text-5xl font-extrabold text-gray-900 dark:text-white tracking-tight mb-5">
            Restoran biznesingiz uchun barcha imkoniyatlar
          </h2>

          <p className="text-gray-600 dark:text-gray-300 text-base sm:text-lg leading-relaxed">
            Zavero bir nechta turli dasturlarning o'rnini bosadi: POS kassa, ofitsiant ilovasi, ombor hisobi, CRM va Director paneli — hammasi yagona platformada.
          </p>
        </div>

        {/* 9 Features Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 sm:gap-8">
          {featuresList.map((item, index) => (
            <motion.div
              key={index}
              initial={{ opacity: 0, y: 25 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, delay: index * 0.08 }}
              className="glass-card p-7 sm:p-8 rounded-3xl border border-gray-200 dark:border-white/10 hover:border-red-500/40 relative overflow-hidden group flex flex-col justify-between transition-all"
            >
              <div className={`absolute top-0 right-0 w-44 h-44 bg-gradient-to-br ${item.gradient} rounded-full blur-2xl group-hover:scale-125 transition-transform duration-500 pointer-events-none`} />

              <div>
                <div className="flex items-center justify-between mb-5">
                  <div className="w-14 h-14 rounded-2xl bg-gray-100 dark:bg-white/[0.04] border border-gray-200 dark:border-white/10 flex items-center justify-center group-hover:scale-110 group-hover:border-red-500/40 transition-all duration-300 shadow-sm">
                    {item.icon}
                  </div>
                  <span className="text-2xl filter drop-shadow">{item.emoji}</span>
                </div>

                <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-3 group-hover:text-red-500 transition-colors">
                  {item.title}
                </h3>

                <p className="text-gray-600 dark:text-gray-400 text-sm leading-relaxed mb-6">
                  {item.description}
                </p>
              </div>

              <div className="pt-4 border-t border-gray-200 dark:border-white/[0.06] space-y-2">
                {item.highlights.map((h, i) => (
                  <div key={i} className="flex items-center gap-2 text-xs text-gray-700 dark:text-gray-300">
                    <span className="w-4 h-4 rounded-full bg-red-500/15 text-red-600 dark:text-red-400 flex items-center justify-center shrink-0">
                      <Check className="w-2.5 h-2.5" />
                    </span>
                    <span>{h}</span>
                  </div>
                ))}
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
};
