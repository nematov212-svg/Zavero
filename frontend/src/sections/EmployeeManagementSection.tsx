import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
  Users,
  Award,
  CheckCircle2,
  Clock,
  TrendingUp,
  DollarSign,
  ShieldCheck,
  Smartphone,
  Star,
} from 'lucide-react';
import { Employee } from '../types';

export const EmployeeManagementSection: React.FC = () => {
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [activeTab, setActiveTab] = useState<'top' | 'attendance' | 'speed'>('top');

  // Fallback demo dataset if unauthenticated on public page
  const fallbackEmployees: Employee[] = [
    {
      id: '1',
      cafeId: 'c1',
      name: 'Nematov Mirzobek',
      role: 'Katta ofitsiant',
      phone: '+998 50 723 04 75',
      ordersCount: 48,
      closedOrdersCount: 46,
      salesAmount: 9400000,
      attendanceStatus: 'Faol ishda',
      rating: 4.9,
      cafe: { name: 'Family Cafe', city: 'Toshkent' },
      createdAt: new Date().toISOString(),
    },
    {
      id: '2',
      cafeId: 'c2',
      name: 'Sherzod Toirov',
      role: 'Katta ofitsiant',
      phone: '+998 93 456 78 90',
      ordersCount: 52,
      closedOrdersCount: 50,
      salesAmount: 11200000,
      attendanceStatus: 'Faol ishda',
      rating: 4.95,
      cafe: { name: 'Samarqand Cafe & Lounge', city: 'Samarqand' },
      createdAt: new Date().toISOString(),
    },
    {
      id: '3',
      cafeId: 'c1',
      name: 'Madina Umarova',
      role: 'Ofitsiant',
      phone: '+998 97 555 44 33',
      ordersCount: 42,
      closedOrdersCount: 41,
      salesAmount: 7800000,
      attendanceStatus: 'Faol ishda',
      rating: 4.8,
      cafe: { name: 'Family Cafe', city: 'Toshkent' },
      createdAt: new Date().toISOString(),
    },
    {
      id: '4',
      cafeId: 'c1',
      name: 'Nilufar Sobirova',
      role: 'Barista',
      phone: '+998 90 999 88 77',
      ordersCount: 56,
      closedOrdersCount: 56,
      salesAmount: 4200000,
      attendanceStatus: 'Tanaffusda',
      rating: 5.0,
      cafe: { name: 'Family Cafe', city: 'Toshkent' },
      createdAt: new Date().toISOString(),
    },
  ];

  return (
    <section className="relative py-28 bg-white dark:bg-[#080A10] border-t border-gray-200 dark:border-white/[0.06] overflow-hidden transition-colors">
      {/* Background ambient lighting */}
      <div className="absolute top-1/2 left-0 w-96 h-96 bg-red-500/5 rounded-full blur-[140px] pointer-events-none" />
      <div className="absolute bottom-0 right-0 w-96 h-96 bg-rose-500/5 rounded-full blur-[140px] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          {/* Left Text Column */}
          <div className="lg:col-span-5 space-y-6">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-xs font-semibold">
              <Users className="w-3.5 h-3.5" />
              <span>Smart HR & KPI Nazorati</span>
            </div>

            <h2 className="text-3xl sm:text-5xl font-extrabold text-gray-900 dark:text-white tracking-tight leading-tight">
              Xodimlaringizni real vaqtda nazorat qiling
            </h2>

            <p className="text-gray-600 dark:text-gray-300 text-base sm:text-lg leading-relaxed">
              Zavero Flutter ofitsiant va kassir ilovalari har bir xodimning harakatini soniyalargacha hisoblab boradi. Shaffof KPI va motivatsiya tizimi savdoni 35% ga oshiradi.
            </p>

            <div className="space-y-4 pt-2">
              <div className="flex items-start gap-3.5">
                <div className="w-9 h-9 rounded-xl bg-red-500/10 border border-red-500/30 flex items-center justify-center text-red-500 shrink-0 mt-0.5">
                  <TrendingUp className="w-5 h-5" />
                </div>
                <div>
                  <h4 className="text-gray-900 dark:text-white font-semibold text-sm">Nechta buyurtma oldi & yopdi</h4>
                  <p className="text-gray-500 dark:text-gray-400 text-xs mt-0.5">Xodimlarning buyurtma olish tezligi va oshxona bilan aloqasi daqiqama-daqiqa ko'rinadi.</p>
                </div>
              </div>

              <div className="flex items-start gap-3.5">
                <div className="w-9 h-9 rounded-xl bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-cyan-600 dark:text-cyan-400 shrink-0 mt-0.5">
                  <DollarSign className="w-5 h-5" />
                </div>
                <div>
                  <h4 className="text-gray-900 dark:text-white font-semibold text-sm">Shaxsiy savdo summasi & choypuli</h4>
                  <p className="text-gray-500 dark:text-gray-400 text-xs mt-0.5">Har bir ofitsiant restoranga keltirgan aniq daromad va bonuslarni avtomatik hisoblash.</p>
                </div>
              </div>

              <div className="flex items-start gap-3.5">
                <div className="w-9 h-9 rounded-xl bg-indigo-500/10 border border-indigo-500/30 flex items-center justify-center text-indigo-600 dark:text-indigo-400 shrink-0 mt-0.5">
                  <Clock className="w-5 h-5" />
                </div>
                <div>
                  <h4 className="text-gray-900 dark:text-white font-semibold text-sm">Davomat & smenani ochish/yopish</h4>
                  <p className="text-gray-500 dark:text-gray-400 text-xs mt-0.5">Kechikishlar, tanaffuslar va ish soatlari Flutter ilovasida PIN orqali qayd etiladi.</p>
                </div>
              </div>
            </div>
          </div>

          {/* Right Live Preview Column */}
          <div className="lg:col-span-7">
            <div className="glass-panel p-6 sm:p-8 rounded-3xl border border-gray-200 dark:border-white/10 bg-white/90 dark:bg-[#0E1322]/90 relative shadow-xl">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between pb-6 border-b border-gray-200 dark:border-white/[0.08] gap-3">
                <div>
                  <div className="flex items-center gap-2">
                    <Award className="w-5 h-5 text-amber-500" />
                    <h3 className="text-lg font-bold text-gray-900 dark:text-white">Top xodimlar reytingi (Jonli)</h3>
                  </div>
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">Bugungi kungi buyurtmalar va tushum bo'yicha</p>
                </div>

                <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-emerald-500/10 border border-emerald-500/30 text-emerald-600 dark:text-emerald-400 self-start sm:self-auto">
                  <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                  Flutter Sync Active
                </span>
              </div>

              {/* Employee Rows */}
              <div className="space-y-4 pt-6">
                {fallbackEmployees.map((emp, index) => (
                  <motion.div
                    key={emp.id}
                    initial={{ opacity: 0, x: 20 }}
                    whileInView={{ opacity: 1, x: 0 }}
                    viewport={{ once: true }}
                    transition={{ duration: 0.4, delay: index * 0.1 }}
                    className="glass-card p-4 rounded-2xl border border-gray-200 dark:border-white/[0.08] hover:border-red-500/30 flex flex-col sm:flex-row sm:items-center justify-between gap-4 transition-all"
                  >
                    <div className="flex items-center gap-3.5">
                      <div className="relative">
                        <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-red-500/20 to-rose-500/20 border border-red-500/30 flex items-center justify-center font-extrabold text-red-600 dark:text-white text-base">
                          {emp.name.split(' ').map(n => n[0]).join('')}
                        </div>
                        <span className="absolute -top-1.5 -left-1.5 w-5 h-5 rounded-full bg-amber-400 text-black text-[10px] font-black flex items-center justify-center shadow">
                          #{index + 1}
                        </span>
                      </div>

                      <div>
                        <div className="flex items-center gap-2">
                          <h4 className="text-sm font-bold text-gray-900 dark:text-white">{emp.name}</h4>
                          <span className="text-[11px] text-amber-500 font-semibold flex items-center gap-0.5">
                            <Star className="w-3 h-3 fill-amber-400 text-amber-400" /> {emp.rating}
                          </span>
                        </div>
                        <p className="text-xs text-gray-500 dark:text-gray-400">{emp.role} • {emp.cafe?.name}</p>
                      </div>
                    </div>

                    <div className="flex items-center justify-between sm:justify-end gap-6 text-xs border-t sm:border-t-0 border-gray-200 dark:border-white/[0.06] pt-2 sm:pt-0">
                      <div className="text-left sm:text-right">
                        <span className="text-gray-500 dark:text-gray-400 block text-[11px]">Buyurtmalar</span>
                        <span className="font-bold text-gray-900 dark:text-white font-mono">{emp.ordersCount} olingan ({emp.closedOrdersCount} yopildi)</span>
                      </div>

                      <div className="text-right">
                        <span className="text-gray-500 dark:text-gray-400 block text-[11px]">Savdo summasi</span>
                        <span className="font-extrabold text-red-600 dark:text-red-400 text-sm font-mono">
                          {emp.salesAmount.toLocaleString('en-US')} so'm
                        </span>
                      </div>

                      <span className={`hidden md:inline-flex px-2 py-0.5 rounded-full text-[11px] font-semibold border ${emp.attendanceStatus === 'Faol ishda'
                        ? 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/30'
                        : 'bg-amber-500/10 text-amber-600 dark:text-amber-400 border-amber-500/30'
                        }`}>
                        {emp.attendanceStatus}
                      </span>
                    </div>
                  </motion.div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};
