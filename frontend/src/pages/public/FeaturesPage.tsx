import React from 'react';
import { FeaturesSection } from '../../sections/FeaturesSection';
import { EmployeeManagementSection } from '../../sections/EmployeeManagementSection';
import { LeadFormSection } from '../../sections/LeadFormSection';
import { Tablet, MonitorCheck, ShieldCheck, Cpu } from 'lucide-react';

export const FeaturesPage: React.FC = () => {
  return (
    <div className="pt-28 pb-20">
      {/* Header */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center mb-16">
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-xs font-semibold mb-4">
          <Cpu className="w-3.5 h-3.5" />
          <span>Platforma Arxitekturasi</span>
        </div>
        <h1 className="text-4xl sm:text-6xl font-black text-gray-900 dark:text-white tracking-tight mb-6">
          Zavero Ekotizimi Imkoniyatlari
        </h1>
        <p className="text-gray-600 dark:text-gray-300 text-lg max-w-3xl mx-auto leading-relaxed">
          Kassadan boshlab oshxona, ombor va xodimlar boshqaruvigacha — biznesingizdagi har bir jarayonni 100% raqamlashtiring.
        </p>

        {/* 3 Devices Visual Pills */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto mt-12 text-left">
          <div className="glass-card p-6 rounded-2xl border border-gray-200 dark:border-white/10">
            <Tablet className="w-8 h-8 text-red-500 mb-3" />
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-1">Flutter Waiter POS</h3>
            <p className="text-xs text-gray-500 dark:text-gray-400">Ofitsiant plansheti va telefoni orqali stolda turib buyurtma olish ilovasi.</p>
          </div>

          <div className="glass-card p-6 rounded-2xl border border-gray-200 dark:border-white/10">
            <MonitorCheck className="w-8 h-8 text-cyan-500 mb-3" />
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-1">Kitchen Display (KDS)</h3>
            <p className="text-xs text-gray-500 dark:text-gray-400">Oshxona va bar xodimlari uchun taom tayyorlanish vaqtini ko'rsatuvchi interaktiv monitor.</p>
          </div>

          <div className="glass-card p-6 rounded-2xl border border-gray-200 dark:border-white/10">
            <ShieldCheck className="w-8 h-8 text-indigo-500 mb-3" />
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-1">Smart Analitika & Monitoring</h3>
            <p className="text-xs text-gray-500 dark:text-gray-400">Dunyoning istalgan nuqtasidan filiallar, tushum va xodimlar natijalarini real vaqtda kuzatish.</p>
          </div>
        </div>
      </div>

      <FeaturesSection />
      <EmployeeManagementSection />
      <LeadFormSection />
    </div>
  );
};
