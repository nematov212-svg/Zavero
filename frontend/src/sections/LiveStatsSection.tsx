import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Store, Users, ShoppingBag, HeartHandshake, RefreshCw, Activity } from 'lucide-react';
import { publicApi } from '../api/publicApi';
import { PublicStats } from '../types';
import { useAnimatedCounter } from '../hooks/useAnimatedCounter';
import { useSocket } from '../hooks/useSocket';

interface StatItemProps {
  label: string;
  value: number;
  suffix?: string;
  icon: React.ReactNode;
  color: string;
  badgeColor: string;
}

const StatCounterCard: React.FC<StatItemProps> = ({
  label,
  value,
  suffix = '+',
  icon,
  color,
  badgeColor,
}) => {
  const animatedValue = useAnimatedCounter(value);

  return (
    <div className="relative glass-card p-6 sm:p-8 rounded-3xl border border-gray-200 dark:border-white/10 hover:border-red-500/40 overflow-hidden group shadow-sm hover:shadow-lg transition-all">
      {/* Background ambient corner glow */}
      <div className={`absolute top-0 right-0 w-32 h-32 ${color} opacity-10 rounded-full blur-2xl group-hover:opacity-20 transition-opacity`} />

      <div className="flex items-center justify-between mb-4">
        <span className="text-xs font-bold tracking-wider uppercase text-gray-500 dark:text-gray-400">
          {label}
        </span>
        <div className={`w-12 h-12 rounded-2xl ${badgeColor} flex items-center justify-center shadow-inner`}>
          {icon}
        </div>
      </div>

      <div className="flex items-baseline gap-1">
        <span className="text-4xl sm:text-5xl font-black tracking-tight text-gray-900 dark:text-white font-mono">
          {animatedValue}
        </span>
        <span className="text-2xl sm:text-3xl font-extrabold text-red-500">
          {suffix}
        </span>
      </div>

      <div className="mt-3 flex items-center gap-1.5 text-xs text-gray-500 dark:text-gray-400 font-medium">
        <span className="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse" />
        <span>Real-time ma'lumotlar bazasi</span>
      </div>
    </div>
  );
};

export const LiveStatsSection: React.FC = () => {
  const [stats, setStats] = useState<PublicStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [lastUpdated, setLastUpdated] = useState<string>('');
  const { socket } = useSocket();

  const fetchStats = async () => {
    try {
      const data = await publicApi.getStatistics();
      setStats(data);
      setLastUpdated(new Date().toLocaleTimeString('uz-UZ'));
    } catch (err) {
      console.error('Failed to fetch public statistics:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();
  }, []);

  // Real-time synchronization
  useEffect(() => {
    if (!socket) return;

    socket.on('stats_updated', () => {
      fetchStats();
    });

    return () => {
      socket.off('stats_updated');
    };
  }, [socket]);

  return (
    <section className="relative py-20 bg-white dark:bg-[#090C16] border-y border-gray-200 dark:border-white/[0.06] overflow-hidden transition-colors">
      {/* Background glow lines */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-3/4 h-32 bg-red-500/5 blur-[100px] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="flex flex-col md:flex-row md:items-end justify-between mb-12 gap-4">
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-xs font-bold mb-3">
              <Activity className="w-3.5 h-3.5 animate-pulse" />
              <span>Real Vaqt Ko'rsatkichlari</span>
            </div>
            <h2 className="text-3xl sm:text-4xl font-black text-gray-900 dark:text-white tracking-tight">
              Jonli Zavero Statistikasi
            </h2>
            <p className="text-gray-600 dark:text-gray-400 text-sm sm:text-base mt-2 max-w-xl">
              Ushbu raqamlar Zavero platformasidagi barcha ulangan cafe va restoranlar faoliyati bo'yicha markaziy PostgreSQL bazasidan real vaqtda yangilanadi.
            </p>
          </div>

          <div className="flex items-center gap-2 text-xs text-gray-600 dark:text-gray-400 bg-white dark:bg-white/[0.04] px-3.5 py-2 rounded-xl border border-gray-200 dark:border-white/10 self-start md:self-auto shadow-sm">
            <RefreshCw className="w-3.5 h-3.5 text-red-500" />
            <span>Oxirgi sinxronizatsiya: {lastUpdated || 'hozirgina'}</span>
          </div>
        </div>

        {/* Dynamic Cards Grid */}
        {isLoading || !stats ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {[1, 2, 3, 4].map((i) => (
              <div
                key={i}
                className="h-44 rounded-3xl bg-gray-200 dark:bg-[#131A2E]/50 border border-gray-200 dark:border-white/10 animate-shimmer"
              />
            ))}
          </div>
        ) : (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6 }}
            className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6"
          >
            <StatCounterCard
              label="Faol Cafelar"
              value={stats.cafes}
              icon={<Store className="w-6 h-6 text-red-500" />}
              color="bg-red-500"
              badgeColor="bg-red-500/10 border border-red-500/20 text-red-500"
            />

            <StatCounterCard
              label="Faol Xodimlar"
              value={stats.employees}
              icon={<Users className="w-6 h-6 text-cyan-500" />}
              color="bg-cyan-500"
              badgeColor="bg-cyan-500/10 border border-cyan-500/20 text-cyan-500"
            />

            <StatCounterCard
              label="Buyurtmalar"
              value={stats.orders}
              icon={<ShoppingBag className="w-6 h-6 text-indigo-500" />}
              color="bg-indigo-500"
              badgeColor="bg-indigo-500/10 border border-indigo-500/20 text-indigo-500"
            />

            <StatCounterCard
              label="Mijozlar"
              value={stats.customers}
              icon={<HeartHandshake className="w-6 h-6 text-amber-500" />}
              color="bg-amber-500"
              badgeColor="bg-amber-500/10 border border-amber-500/20 text-amber-500"
            />
          </motion.div>
        )}
      </div>
    </section>
  );
};
