import React from 'react';
import { ShieldCheck, Server, Smartphone, Award, Cpu, Zap, Heart } from 'lucide-react';
import { LeadFormSection } from '../../sections/LeadFormSection';

export const AboutPage: React.FC = () => {
  return (
    <div className="pt-28 pb-20">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-3xl mx-auto mb-20">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-xs font-semibold mb-4">
            <Heart className="w-3.5 h-3.5" />
            <span>Bizning Missiyamiz</span>
          </div>
          <h1 className="text-4xl sm:text-6xl font-black text-gray-900 dark:text-white tracking-tight mb-6">
            O'zbekistonda restoran industriyasini o'zgartirmoqdamiz
          </h1>
          <p className="text-gray-600 dark:text-gray-300 text-lg leading-relaxed">
            Zavero — oddiy dastur emas, balki kafe va restoranlarga raqamli davrda eng yuqori daromad va tezlikka erishishga ko'maklashuvchi to'liq texnologik infratuzilma.
          </p>
        </div>

        {/* 4 Core Pillars */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-24">
          <div className="glass-card p-6 rounded-3xl border border-gray-200 dark:border-white/10">
            <Smartphone className="w-10 h-10 text-red-500 mb-4" />
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2">Native Flutter Dastur</h3>
            <p className="text-xs text-gray-500 dark:text-gray-400 leading-relaxed">
              Eng yuqori 60-120 fps tezlik, planshetlarda silliq ishlash va oflayn rejimda ham to'liq ishonchlilik.
            </p>
          </div>

          <div className="glass-card p-6 rounded-3xl border border-gray-200 dark:border-white/10">
            <Server className="w-10 h-10 text-cyan-500 mb-4" />
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2">PostgreSQL & Cloud API</h3>
            <p className="text-xs text-gray-500 dark:text-gray-400 leading-relaxed">
              Korporativ darajadagi ACID tranzaksiyalari va har soniyada minglab buyurtmalarni qayta ishlash qobiliyati.
            </p>
          </div>

          <div className="glass-card p-6 rounded-3xl border border-gray-200 dark:border-white/10">
            <ShieldCheck className="w-10 h-10 text-indigo-500 mb-4" />
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2">Bank Darajasidagi Xavfsizlik</h3>
            <p className="text-xs text-gray-500 dark:text-gray-400 leading-relaxed">
              JWT tokenlar, bcrypt shifrlash, rol asosidagi kirish huquqlari va ma'lumotlarning avtomatik zaxira nusxalari.
            </p>
          </div>

          <div className="glass-card p-6 rounded-3xl border border-gray-200 dark:border-white/10">
            <Zap className="w-10 h-10 text-amber-500 mb-4" />
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2">Socket.IO Real-time</h3>
            <p className="text-xs text-gray-500 dark:text-gray-400 leading-relaxed">
              Stoldan oshxonaga, kassadan asosiy boshqaruv paneliga ma'lumotlar kechikishsiz 0.1 soniyada uzatiladi.
            </p>
          </div>
        </div>
      </div>

      <LeadFormSection />
    </div>
  );
};
