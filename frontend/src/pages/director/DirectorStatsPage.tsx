import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
  TrendingUp,
  BarChart3,
  DollarSign,
  ShoppingBag,
  Users,
  Award,
  Calendar,
  CreditCard,
  PieChart,
} from 'lucide-react';
import { directorApi } from '../../api/directorApi';
import { DirectorDashboardData, Employee } from '../../types';

export const DirectorStatsPage: React.FC = () => {
  const [data, setData] = useState<DirectorDashboardData | null>(null);
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const loadStats = async () => {
      try {
        const [dashRes, empRes] = await Promise.all([
          directorApi.getDashboard(),
          directorApi.getEmployees(),
        ]);
        if (dashRes.success && dashRes.data) setData(dashRes.data);
        if (empRes.success && empRes.data) setEmployees(empRes.data);
      } catch (err) {
        console.error('Failed to load stats:', err);
      } finally {
        setIsLoading(false);
      }
    };
    loadStats();
  }, []);

  if (isLoading || !data) {
    return (
      <div className="space-y-6 animate-pulse">
        <div className="h-8 bg-white/10 rounded-xl w-64" />
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-40 bg-[#131A2E]/50 rounded-2xl" />
          ))}
        </div>
      </div>
    );
  }

  const { overview } = data;

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight flex items-center gap-3">
          <BarChart3 className="w-7 h-7 text-emerald-400" />
          <span>Platforma Analitikasi & Savdo</span>
        </h1>
        <p className="text-xs sm:text-sm text-gray-400 mt-1">
          Zavero platformasining moliyaviy hisobotlari, konversiya va xodimlar unumdorligi
        </p>
      </div>

      {/* Top 3 KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="glass-card p-6 sm:p-7 rounded-3xl border border-white/10">
          <div className="flex items-center justify-between mb-4">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Jami Savdo Aylanmasi</span>
            <div className="w-10 h-10 rounded-xl bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center text-emerald-400">
              <DollarSign className="w-5 h-5" />
            </div>
          </div>
          <div className="text-3xl font-black text-white font-mono">
            {overview.totalRevenue.toLocaleString('en-US')} so'm
          </div>
          <span className="text-xs text-emerald-400 font-semibold mt-3 flex items-center gap-1">
            <TrendingUp className="w-3.5 h-3.5" /> Barcha filiallar umumiy tushumi
          </span>
        </div>

        <div className="glass-card p-6 sm:p-7 rounded-3xl border border-white/10">
          <div className="flex items-center justify-between mb-4">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">O'rtacha Chek Hajmi</span>
            <div className="w-10 h-10 rounded-xl bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-cyan-400">
              <ShoppingBag className="w-5 h-5" />
            </div>
          </div>
          <div className="text-3xl font-black text-cyan-400 font-mono">
            {overview.orders > 0 ? Math.round(overview.totalRevenue / overview.orders).toLocaleString('en-US') : 0} so'm
          </div>
          <span className="text-xs text-gray-400 mt-3 block">
            Jami {overview.orders.toLocaleString()} ta buyurtma asosida
          </span>
        </div>

        <div className="glass-card p-6 sm:p-7 rounded-3xl border border-white/10">
          <div className="flex items-center justify-between mb-4">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Leadlar Konversiyasi</span>
            <div className="w-10 h-10 rounded-xl bg-indigo-500/10 border border-indigo-500/30 flex items-center justify-center text-indigo-400">
              <Users className="w-5 h-5" />
            </div>
          </div>
          <div className="text-3xl font-black text-indigo-400 font-mono">
            {overview.totalLeads > 0 ? Math.round((overview.activeCafes / overview.totalLeads) * 100) : 0}%
          </div>
          <span className="text-xs text-gray-400 mt-3 block">
            {overview.totalLeads} ta arizadan {overview.activeCafes} ta faol hamkor
          </span>
        </div>
      </div>

      {/* Grid: Payment Method Distribution & Top Staff */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        {/* Payment Methods Breakdown */}
        <div className="lg:col-span-5 glass-panel p-6 sm:p-7 rounded-3xl border border-white/10 bg-[#0E1322]">
          <h3 className="text-lg font-bold text-white mb-1 flex items-center gap-2">
            <CreditCard className="w-4 h-4 text-emerald-400" />
            To'lov Usullari Taqsimoti
          </h3>
          <p className="text-xs text-gray-400 mb-6">Mijozlar to'lovlarining taqsimlanishi</p>

          <div className="space-y-4">
            {[
              { label: 'Click & Payme QR', percent: 56, color: 'bg-emerald-500', amount: '56%' },
              { label: 'Bank kartalari (Humo / Uzcard)', percent: 34, color: 'bg-cyan-500', amount: '34%' },
              { label: 'Naqd pul', percent: 10, color: 'bg-amber-500', amount: '10%' },
            ].map((p, i) => (
              <div key={i} className="space-y-1.5">
                <div className="flex justify-between text-xs">
                  <span className="text-gray-300 font-medium">{p.label}</span>
                  <span className="text-white font-bold font-mono">{p.amount}</span>
                </div>
                <div className="h-2.5 rounded-full bg-white/[0.06] overflow-hidden">
                  <div
                    className={`h-full ${p.color} rounded-full transition-all duration-1000`}
                    style={{ width: `${p.percent}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Top Staff Leaderboard */}
        <div className="lg:col-span-7 glass-panel p-6 sm:p-7 rounded-3xl border border-white/10 bg-[#0E1322]">
          <h3 className="text-lg font-bold text-white mb-1 flex items-center gap-2">
            <Award className="w-4 h-4 text-amber-400" />
            Xodimlar Unumdorligi (Top Ofitsiantlar)
          </h3>
          <p className="text-xs text-gray-400 mb-5">Savdo va buyurtmalar bo'yicha eng yaxshi xodimlar</p>

          <div className="space-y-3">
            {employees.slice(0, 5).map((emp, i) => (
              <div
                key={emp.id}
                className="glass-card p-3.5 rounded-2xl border border-white/[0.06] flex items-center justify-between gap-3"
              >
                <div className="flex items-center gap-3">
                  <span className="w-6 h-6 rounded-full bg-white/[0.06] text-amber-400 text-xs font-bold flex items-center justify-center shrink-0">
                    #{i + 1}
                  </span>
                  <div>
                    <h4 className="text-sm font-bold text-white">{emp.name}</h4>
                    <span className="text-xs text-gray-400">{emp.role} • {emp.cafe?.name}</span>
                  </div>
                </div>

                <div className="text-right">
                  <div className="text-sm font-bold text-emerald-400 font-mono">
                    {emp.salesAmount.toLocaleString('en-US')} so'm
                  </div>
                  <span className="text-[11px] text-gray-400 font-mono">
                    {emp.ordersCount} buyurtma ({emp.closedOrdersCount} yopilgan)
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};
