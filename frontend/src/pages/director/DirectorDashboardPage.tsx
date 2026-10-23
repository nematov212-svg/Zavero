import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
  Store,
  Users,
  ShoppingBag,
  DollarSign,
  PhoneCall,
  Clock,
  ArrowRight,
  TrendingUp,
  RefreshCw,
  Smartphone,
  CheckCircle,
} from 'lucide-react';
import { directorApi } from '../../api/directorApi';
import { DirectorDashboardData, Lead } from '../../types';
import { Badge } from '../../components/common/Badge';
import { useSocket } from '../../hooks/useSocket';

export const DirectorDashboardPage: React.FC = () => {
  const [data, setData] = useState<DirectorDashboardData | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const { socket } = useSocket(true);

  const fetchDashboard = async () => {
    try {
      const res = await directorApi.getDashboard();
      if (res.success && res.data) {
        setData(res.data);
      }
    } catch (err) {
      console.error('Failed to load director dashboard:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchDashboard();
  }, []);

  // Real-time synchronization via Socket.io
  useEffect(() => {
    if (!socket) return;
    socket.on('new_lead', () => fetchDashboard());
    socket.on('lead_status_updated', () => fetchDashboard());
    socket.on('cafe_updated', () => fetchDashboard());
    socket.on('stats_updated', () => fetchDashboard());

    return () => {
      socket.off('new_lead');
      socket.off('lead_status_updated');
      socket.off('cafe_updated');
      socket.off('stats_updated');
    };
  }, [socket]);

  if (isLoading || !data) {
    return (
      <div className="space-y-6 animate-pulse">
        <div className="h-8 bg-white/10 rounded-xl w-64" />
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="h-32 bg-[#131A2E]/50 rounded-2xl" />
          ))}
        </div>
      </div>
    );
  }

  const { overview, recentLeads, recentCafes } = data;

  return (
    <div className="space-y-8">
      {/* Page Header without manual add button */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
            Director Boshqaruv Markazi
          </h1>
          <p className="text-xs sm:text-sm text-gray-400 mt-1">
            Zavero platformasining markaziy real vaqt statistikasi va mijozlar arizalari
          </p>
        </div>

        <div className="flex items-center gap-3">
          <div className="px-3.5 py-1.5 rounded-xl bg-red-500/10 border border-red-500/20 text-red-500 text-xs font-semibold flex items-center gap-2">
            <Smartphone className="w-3.5 h-3.5" />
            <span>Zavero Flutter Cloud Hub</span>
          </div>

          <button
            onClick={fetchDashboard}
            className="p-2.5 rounded-xl text-gray-400 hover:text-white bg-white/[0.05] border border-white/10 transition-colors cursor-pointer"
            title="Ma'lumotlarni yangilash"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* 4 Overview Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <div className="glass-card p-6 rounded-3xl border border-white/10 hover:border-red-500/30 transition-all">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Faol Cafelar</span>
            <div className="w-10 h-10 rounded-xl bg-red-500/10 border border-red-500/30 flex items-center justify-center text-red-500">
              <Store className="w-5 h-5" />
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-black text-white font-mono">{overview.activeCafes}</span>
            <span className="text-xs text-gray-400">/ {overview.totalCafes} jami</span>
          </div>
          <Link to="/director/cafes" className="mt-3 text-xs text-red-400 hover:underline flex items-center gap-1 font-medium">
            Ulangan cafelarni ko'rish <ArrowRight className="w-3 h-3" />
          </Link>
        </div>

        <div className="glass-card p-6 rounded-3xl border border-white/10 hover:border-cyan-500/30 transition-all">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Yangi Mijozlar (Leadlar)</span>
            <div className="w-10 h-10 rounded-xl bg-cyan-500/10 border border-cyan-500/30 flex items-center justify-center text-cyan-400">
              <Users className="w-5 h-5" />
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-black text-white font-mono">{overview.newLeads}</span>
            <span className="text-xs text-cyan-400 font-semibold">yangi kutmoqda</span>
          </div>
          <Link to="/director/leads" className="mt-3 text-xs text-cyan-400 hover:underline flex items-center gap-1 font-medium">
            Mijozlar ro'yxatiga o'tish <ArrowRight className="w-3 h-3" />
          </Link>
        </div>

        <div className="glass-card p-6 rounded-3xl border border-white/10 hover:border-indigo-500/30 transition-all">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Jami Buyurtmalar (Zakazlar)</span>
            <div className="w-10 h-10 rounded-xl bg-indigo-500/10 border border-indigo-500/30 flex items-center justify-center text-indigo-400">
              <ShoppingBag className="w-5 h-5" />
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-black text-white font-mono">{overview.orders.toLocaleString()}</span>
            <span className="text-xs text-gray-400">zakaz</span>
          </div>
          <span className="mt-3 text-xs text-gray-400 block font-medium">
            {overview.employees} nafar xodim xizmatida
          </span>
        </div>

        <div className="glass-card p-6 rounded-3xl border border-white/10 hover:border-amber-500/30 transition-all">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Platforma Savdosi</span>
            <div className="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center text-amber-400">
              <DollarSign className="w-5 h-5" />
            </div>
          </div>
          <div className="flex items-baseline gap-1">
            <span className="text-2xl sm:text-3xl font-black text-emerald-400 font-mono">
              {(overview.totalRevenue / 1000000).toFixed(1)}M
            </span>
            <span className="text-xs text-gray-400">so'm</span>
          </div>
          <span className="mt-3 text-xs text-emerald-400/90 flex items-center gap-1 font-semibold">
            <TrendingUp className="w-3.5 h-3.5" /> Real tushum hisobi
          </span>
        </div>
      </div>

      {/* Grid: Recent Leads & Recent Cafes */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        {/* Recent Leads (Left 7 Cols) */}
        <div className="lg:col-span-7 glass-panel p-6 sm:p-7 rounded-3xl border border-white/10 bg-[#0E1322]">
          <div className="flex items-center justify-between pb-4 border-b border-white/[0.08] mb-5">
            <div>
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                <Users className="w-4 h-4 text-red-500" />
                Oxirgi kelgan arizalar (Leadlar)
              </h3>
              <p className="text-xs text-gray-400 mt-0.5">Web saytdagi formadan tushgan arizalar</p>
            </div>
            <Link to="/director/leads" className="text-xs font-semibold text-red-400 hover:text-red-300">
              Barchasi ({overview.totalLeads}) →
            </Link>
          </div>

          <div className="space-y-3">
            {recentLeads.length === 0 ? (
              <p className="text-xs text-gray-400 text-center py-8">Hozircha yangi arizalar yo'q</p>
            ) : (
              recentLeads.map((lead: Lead) => (
                <div
                  key={lead.id}
                  className="glass-card p-4 rounded-2xl border border-white/[0.06] hover:border-red-500/30 flex flex-col sm:flex-row sm:items-center justify-between gap-3 transition-all"
                >
                  <div>
                    <div className="flex items-center gap-2">
                      <h4 className="text-sm font-bold text-white">{lead.name}</h4>
                      <Badge status={lead.status} />
                    </div>
                    <div className="text-xs text-gray-300 font-semibold mt-1">
                      {lead.businessName} • <span className="text-gray-400">{lead.city}</span>
                    </div>
                    {lead.message && (
                      <p className="text-xs text-gray-400 line-clamp-1 italic mt-1">
                        "{lead.message}"
                      </p>
                    )}
                  </div>

                  <div className="flex items-center gap-2 self-start sm:self-auto shrink-0">
                    <a
                      href={`tel:${lead.phone}`}
                      className="px-3 py-1.5 rounded-xl bg-red-500/15 hover:bg-red-500 text-red-400 hover:text-white text-xs font-bold flex items-center gap-1.5 transition-all"
                      title="Qo'ng'iroq qilish"
                    >
                      <PhoneCall className="w-3.5 h-3.5" />
                      <span>{lead.phone}</span>
                    </a>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Connected Cafes (Right 5 Cols) */}
        <div className="lg:col-span-5 glass-panel p-6 sm:p-7 rounded-3xl border border-white/10 bg-[#0E1322]">
          <div className="flex items-center justify-between pb-4 border-b border-white/[0.08] mb-5">
            <div>
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                <Store className="w-4 h-4 text-cyan-400" />
                Flutter orqali ulangan Cafelar
              </h3>
              <p className="text-xs text-gray-400 mt-0.5">Ilova bilan bog'langan restoranlar</p>
            </div>
            <Link to="/director/cafes" className="text-xs font-semibold text-cyan-400 hover:text-cyan-300">
              Barchasi ({overview.totalCafes}) →
            </Link>
          </div>

          <div className="space-y-3">
            {recentCafes.map((cafe) => (
              <div
                key={cafe.id}
                className="glass-card p-4 rounded-2xl border border-white/[0.06] hover:border-cyan-500/30 flex items-center justify-between gap-3 transition-all"
              >
                <div>
                  <h4 className="text-sm font-bold text-white">{cafe.name}</h4>
                  <p className="text-xs text-gray-400">{cafe.city} • {cafe.activeTables} ta stol</p>
                  <span className="text-[10px] font-mono text-gray-500 block mt-1">
                    API: {cafe.apiKey?.slice(0, 16)}...
                  </span>
                </div>
                <Badge status={cafe.status} />
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};
