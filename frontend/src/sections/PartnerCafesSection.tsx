import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Utensils, MapPin, CheckCircle, Sparkles, Building2, Layers } from 'lucide-react';
import { publicApi } from '../api/publicApi';
import { Cafe } from '../types';
import { useSocket } from '../hooks/useSocket';
import { Badge } from '../components/common/Badge';

export const PartnerCafesSection: React.FC = () => {
  const [cafes, setCafes] = useState<Cafe[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const { socket } = useSocket();

  const fetchCafes = async () => {
    try {
      const res = await publicApi.getCafes();
      if (res.success && res.data) {
        setCafes(res.data);
      }
    } catch (err) {
      console.error('Failed to load partner cafes:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchCafes();
  }, []);

  // Sync real-time when Director adds/updates a cafe
  useEffect(() => {
    if (!socket) return;
    socket.on('stats_updated', () => fetchCafes());
    socket.on('cafe_updated', () => fetchCafes());

    return () => {
      socket.off('stats_updated');
      socket.off('cafe_updated');
    };
  }, [socket]);

  return (
    <section className="relative py-24 bg-white dark:bg-[#080A10] overflow-hidden transition-colors">
      {/* Ambient background blur */}
      <div className="absolute top-1/3 left-10 w-96 h-96 bg-red-500/5 rounded-full blur-[140px] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="text-center max-w-3xl mx-auto mb-16">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-xs font-bold mb-4">
            <Building2 className="w-3.5 h-3.5" />
            <span>Biznes Hamkorlarimiz</span>
          </div>

          <h2 className="text-3xl sm:text-5xl font-black text-gray-900 dark:text-white tracking-tight mb-4">
            Zavero bilan ishlayotgan bizneslar
          </h2>

          <p className="text-gray-600 dark:text-gray-300 text-base sm:text-lg mb-6 leading-relaxed">
            Bugungi kunda nechta cafe va restaurant Zavero tizimidan foydalanayotganini real vaqtda ko'ring.
          </p>

          {/* Dynamic Database Counter Banner */}
          <div className="inline-flex items-center justify-center gap-2 sm:gap-3 px-4 sm:px-6 py-2 sm:py-2.5 rounded-2xl glass-panel border border-red-500/30 bg-red-500/10 shadow-lg shadow-red-500/10 max-w-full">
            <span className="w-2.5 h-2.5 rounded-full bg-red-500 animate-ping shrink-0" />
            <span className="text-sm sm:text-lg md:text-xl font-bold text-gray-900 dark:text-white font-mono leading-tight">
              <span className="text-red-600 dark:text-red-500 font-black text-xl sm:text-2xl">{cafes.length}</span> ta cafe Zavero'dan foydalanmoqda
            </span>
          </div>
        </div>

        {/* Cafes Cards Grid */}
        {isLoading ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[1, 2].map((i) => (
              <div key={i} className="h-64 rounded-3xl bg-gray-200 dark:bg-[#131A2E]/50 border border-gray-200 dark:border-white/10 animate-shimmer" />
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {cafes.map((cafe, index) => (
              <motion.div
                key={cafe.id}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.5, delay: index * 0.1 }}
                className="glass-card p-6 sm:p-7 rounded-3xl border border-gray-200 dark:border-white/10 hover:border-red-500/40 relative overflow-hidden group flex flex-col justify-between"
              >
                <div className="absolute top-0 right-0 w-32 h-32 bg-red-500/10 rounded-full blur-2xl group-hover:bg-red-500/20 transition-all" />

                <div>
                  <div className="flex items-center justify-between mb-4">
                    <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-red-500/20 to-amber-500/20 border border-red-500/30 flex items-center justify-center text-red-600 dark:text-red-400">
                      <Utensils className="w-6 h-6" />
                    </div>
                    <Badge status="ACTIVE" />
                  </div>

                  <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-2 group-hover:text-red-600 dark:group-hover:text-red-400 transition-colors">
                    {cafe.name}
                  </h3>

                  <div className="space-y-2 text-xs text-gray-500 dark:text-gray-400 mb-6">
                    <div className="flex items-center gap-2">
                      <MapPin className="w-3.5 h-3.5 text-red-500 shrink-0" />
                      <span className="text-gray-700 dark:text-gray-300 font-medium">{cafe.city}, {cafe.address}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <Layers className="w-3.5 h-3.5 text-amber-500 shrink-0" />
                      <span>{cafe.activeTables} ta faol stol • Zavero Cloud POS</span>
                    </div>
                  </div>
                </div>

                <div className="pt-4 border-t border-gray-200 dark:border-white/[0.08] flex items-center justify-between text-xs">
                  <span className="text-emerald-600 dark:text-emerald-400 font-semibold flex items-center gap-1.5">
                    <CheckCircle className="w-4 h-4 text-emerald-500" /> Tizim to'liq ishga tushirilgan
                  </span>
                  <span className="text-gray-400 text-[11px] font-mono">
                    {new Date(cafe.createdAt).toLocaleDateString('uz-UZ')}
                  </span>
                </div>
              </motion.div>
            ))}

            {/* "Sizning restoraningiz bu yerda bo'lishi mumkin" card */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, delay: 0.3 }}
              className="glass-card p-6 sm:p-7 rounded-3xl border border-dashed border-red-500/40 bg-red-500/[0.03] flex flex-col justify-between items-center text-center group cursor-pointer hover:border-red-500"
              onClick={() => {
                const el = document.getElementById('contact-form');
                if (el) el.scrollIntoView({ behavior: 'smooth' });
              }}
            >
              <div className="w-12 h-12 rounded-2xl bg-red-500/10 border border-red-500/30 flex items-center justify-center text-red-500 mb-4 group-hover:scale-110 transition-transform">
                <Sparkles className="w-6 h-6 animate-pulse" />
              </div>

              <div>
                <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2">
                  Sizning restoraningiz keyingisi bo'lsin!
                </h3>
                <p className="text-xs text-gray-500 dark:text-gray-400 max-w-xs mb-4">
                  Zavero tizimini bugunoq o'rnating va biznesingiz samaradorligini 40% ga oshiring.
                </p>
              </div>

              <span className="text-xs font-bold text-red-600 dark:text-red-400 bg-red-500/10 px-4 py-2 rounded-xl border border-red-500/30 group-hover:bg-red-600 group-hover:text-white transition-all">
                Arizani qoldirish →
              </span>
            </motion.div>
          </div>
        )}
      </div>
    </section>
  );
};
