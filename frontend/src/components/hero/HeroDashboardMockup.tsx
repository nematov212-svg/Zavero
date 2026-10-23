import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  UtensilsCrossed,
  Users,
  LayoutGrid,
  TrendingUp,
  Clock,
  CheckCircle2,
  BellRing,
  Coffee,
  Smartphone,
  ChevronRight,
  Sparkles,
} from 'lucide-react';

export const HeroDashboardMockup: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'orders' | 'tables' | 'staff' | 'stats'>('orders');
  const [pulseNewOrder, setPulseNewOrder] = useState(false);

  // Auto-switch tabs periodically to demonstrate ecosystem if user hasn't interacted
  useEffect(() => {
    const tabs: Array<'orders' | 'tables' | 'staff' | 'stats'> = ['orders', 'tables', 'staff', 'stats'];
    let index = 0;
    const interval = setInterval(() => {
      index = (index + 1) % tabs.length;
      setActiveTab(tabs[index]);
    }, 5500);

    return () => clearInterval(interval);
  }, []);

  // Periodic pulse effect for real-time vibe
  useEffect(() => {
    const pulseInterval = setInterval(() => {
      setPulseNewOrder(true);
      setTimeout(() => setPulseNewOrder(false), 2000);
    }, 8000);
    return () => clearInterval(pulseInterval);
  }, []);

  return (
    <div className="relative w-full max-w-5xl mx-auto mt-12 select-none group perspective-1000">
      {/* Dynamic ambient halo behind mockup */}
      <div className="absolute -inset-1 bg-gradient-to-r from-red-600/20 via-rose-500/20 to-amber-500/20 rounded-3xl blur-2xl opacity-75 group-hover:opacity-100 transition duration-1000" />

      {/* Main Container */}
      <div className="relative glass-panel bg-[#0C101D]/90 dark:bg-[#0C101D]/90 border border-gray-200 dark:border-white/[0.12] rounded-2xl md:rounded-3xl shadow-2xl overflow-hidden backdrop-blur-2xl">
        {/* Top Window Bar */}
        <div className="flex items-center justify-between px-4 sm:px-6 py-3.5 border-b border-white/[0.08] bg-[#090C16]/80">
          <div className="flex items-center gap-2">
            <span className="w-3 h-3 rounded-full bg-red-500 inline-block" />
            <span className="w-3 h-3 rounded-full bg-yellow-500 inline-block" />
            <span className="w-3 h-3 rounded-full bg-emerald-500 inline-block" />
            <span className="ml-3 text-xs font-mono text-gray-400 hidden sm:inline-flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
              zavero.fast/terminal — Family Cafe (Live Terminal)
            </span>
          </div>

          <div className="flex items-center gap-2 sm:gap-3">
            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-red-500/15 border border-red-500/30 text-[11px] font-bold text-red-400">
              <span className="w-1.5 h-1.5 rounded-full bg-red-500 animate-ping" />
              Zavero Flutter POS Online
            </span>
            <div className="w-7 h-7 rounded-lg bg-white/[0.06] flex items-center justify-center text-gray-300">
              <Smartphone className="w-4 h-4 text-red-400" />
            </div>
          </div>
        </div>

        {/* Dashboard Navigation Tabs */}
        <div className="flex items-center justify-start overflow-x-auto px-4 sm:px-6 py-2.5 gap-2 border-b border-white/[0.06] bg-[#0E1322]/40 scrollbar-none">
          <button
            onClick={() => setActiveTab('orders')}
            className={`flex items-center gap-2 px-3.5 py-1.5 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
              activeTab === 'orders'
                ? 'bg-red-600 text-white shadow-md shadow-red-500/30 font-bold'
                : 'text-gray-400 hover:text-white hover:bg-white/[0.05]'
            }`}
          >
            <UtensilsCrossed className="w-3.5 h-3.5" />
            Buyurtmalar
            <span className={`px-1.5 py-0.2 rounded-full text-[10px] ${activeTab === 'orders' ? 'bg-black/20 text-white font-bold' : 'bg-red-500/20 text-red-400'}`}>
              8 faol
            </span>
          </button>

          <button
            onClick={() => setActiveTab('tables')}
            className={`flex items-center gap-2 px-3.5 py-1.5 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
              activeTab === 'tables'
                ? 'bg-red-600 text-white shadow-md shadow-red-500/30 font-bold'
                : 'text-gray-400 hover:text-white hover:bg-white/[0.05]'
            }`}
          >
            <LayoutGrid className="w-3.5 h-3.5" />
            Stollar
            <span className="px-1.5 py-0.2 rounded-full text-[10px] bg-white/[0.08] text-gray-300">
              14/18 band
            </span>
          </button>

          <button
            onClick={() => setActiveTab('staff')}
            className={`flex items-center gap-2 px-3.5 py-1.5 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
              activeTab === 'staff'
                ? 'bg-red-600 text-white shadow-md shadow-red-500/30 font-bold'
                : 'text-gray-400 hover:text-white hover:bg-white/[0.05]'
            }`}
          >
            <Users className="w-3.5 h-3.5" />
            Xodimlar
            <span className="px-1.5 py-0.2 rounded-full text-[10px] bg-white/[0.08] text-gray-300">
              7 navbatda
            </span>
          </button>

          <button
            onClick={() => setActiveTab('stats')}
            className={`flex items-center gap-2 px-3.5 py-1.5 rounded-xl text-xs font-semibold transition-all shrink-0 cursor-pointer ${
              activeTab === 'stats'
                ? 'bg-red-600 text-white shadow-md shadow-red-500/30 font-bold'
                : 'text-gray-400 hover:text-white hover:bg-white/[0.05]'
            }`}
          >
            <TrendingUp className="w-3.5 h-3.5" />
            Statistika & Savdo
          </button>
        </div>

        {/* Live notification pill */}
        {pulseNewOrder && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0 }}
            className="mx-4 sm:mx-6 mt-3 px-3.5 py-2 rounded-xl bg-gradient-to-r from-red-500/20 via-rose-500/20 to-transparent border border-red-500/40 flex items-center justify-between text-xs"
          >
            <div className="flex items-center gap-2">
              <BellRing className="w-4 h-4 text-red-400 animate-bounce" />
              <span className="text-white font-medium">🔔 Yangi buyurtma keldi:</span>
              <span className="text-red-300 font-bold">Stol #4 • Ribeye Steyk x 2, Kofe x 2</span>
            </div>
            <span className="text-gray-400 text-[11px] hidden sm:inline">Hozirgina • Ofitsiant: Bobur</span>
          </motion.div>
        )}

        {/* Dynamic Tab Body */}
        <div className="p-4 sm:p-6 min-h-[340px]">
          <AnimatePresence mode="wait">
            {activeTab === 'orders' && (
              <motion.div
                key="orders"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ duration: 0.3 }}
                className="grid grid-cols-1 md:grid-cols-3 gap-4"
              >
                {/* Order Card 1 */}
                <div className="glass-card rounded-2xl p-4 border border-red-500/30 bg-[#12192C]/90 relative overflow-hidden">
                  <div className="absolute top-0 right-0 w-24 h-24 bg-red-500/10 rounded-full blur-xl pointer-events-none" />
                  <div className="flex items-center justify-between mb-3">
                    <span className="text-xs font-mono font-bold text-red-400">#ZV-1327</span>
                    <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                      Oshxonada tayyor
                    </span>
                  </div>
                  <h4 className="text-base font-bold text-white mb-1">Stol #7 (VIP Xona)</h4>
                  <p className="text-xs text-gray-400 mb-3">Ofitsiant: Bobur M. • 4 kishi</p>
                  <div className="space-y-1.5 text-xs text-gray-300 border-t border-white/[0.06] pt-2 mb-3">
                    <div className="flex justify-between">
                      <span>1x Ribeye Steyk (Medium)</span>
                      <span className="font-semibold text-white">125,000</span>
                    </div>
                    <div className="flex justify-between">
                      <span>2x Pitsa Pepperoni 32cm</span>
                      <span className="font-semibold text-white">156,000</span>
                    </div>
                    <div className="flex justify-between">
                      <span>2x Americano kofe</span>
                      <span className="font-semibold text-white">40,000</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between border-t border-white/[0.08] pt-2 text-xs">
                    <span className="text-gray-400">Jami hisob:</span>
                    <span className="text-sm font-extrabold text-red-400">321,000 so'm</span>
                  </div>
                </div>

                {/* Order Card 2 */}
                <div className="glass-card rounded-2xl p-4 border border-cyan-500/20 bg-[#12192C]/70">
                  <div className="flex items-center justify-between mb-3">
                    <span className="text-xs font-mono font-bold text-cyan-400">#ZV-1326</span>
                    <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-cyan-500/20 text-cyan-400 border border-cyan-500/30">
                      Tayyorlanmoqda
                    </span>
                  </div>
                  <h4 className="text-base font-bold text-white mb-1">Stol #3 (Terrasa)</h4>
                  <p className="text-xs text-gray-400 mb-3">Ofitsiant: Madina U. • 2 kishi</p>
                  <div className="space-y-1.5 text-xs text-gray-300 border-t border-white/[0.06] pt-2 mb-3">
                    <div className="flex justify-between">
                      <span>2x Kappuchino Grande</span>
                      <span className="font-semibold text-white">48,000</span>
                    </div>
                    <div className="flex justify-between">
                      <span>2x Chizkeyk San-Sebastyan</span>
                      <span className="font-semibold text-white">76,000</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between border-t border-white/[0.08] pt-2 text-xs">
                    <span className="text-gray-400">Jami hisob:</span>
                    <span className="text-sm font-extrabold text-cyan-400">124,000 so'm</span>
                  </div>
                </div>

                {/* Order Card 3 */}
                <div className="glass-card rounded-2xl p-4 border border-white/[0.08] bg-[#12192C]/70">
                  <div className="flex items-center justify-between mb-3">
                    <span className="text-xs font-mono font-bold text-amber-400">#ZV-1325</span>
                    <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-amber-500/20 text-amber-400 border border-amber-500/30">
                      To'lov kutilmoqda
                    </span>
                  </div>
                  <h4 className="text-base font-bold text-white mb-1">Stol #12 (Katta zal)</h4>
                  <p className="text-xs text-gray-400 mb-3">Ofitsiant: Javohir K. • 6 kishi</p>
                  <div className="space-y-1.5 text-xs text-gray-300 border-t border-white/[0.06] pt-2 mb-3">
                    <div className="flex justify-between">
                      <span>4x Tom Yum Sho'rva</span>
                      <span className="font-semibold text-white">272,000</span>
                    </div>
                    <div className="flex justify-between">
                      <span>2x Sezar Salati</span>
                      <span className="font-semibold text-white">92,000</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between border-t border-white/[0.08] pt-2 text-xs">
                    <span className="text-gray-400">Jami hisob:</span>
                    <span className="text-sm font-extrabold text-amber-400">364,000 so'm</span>
                  </div>
                </div>
              </motion.div>
            )}

            {activeTab === 'tables' && (
              <motion.div
                key="tables"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ duration: 0.3 }}
                className="space-y-4"
              >
                <div className="flex items-center justify-between text-xs text-gray-400 pb-2 border-b border-white/[0.06]">
                  <span className="font-medium">Zallar: Asosiy zal (12 stol) | Terrasa (6 stol)</span>
                  <div className="flex items-center gap-4">
                    <span className="flex items-center gap-1.5">
                      <span className="w-2.5 h-2.5 rounded-full bg-red-500" /> Band (14)
                    </span>
                    <span className="flex items-center gap-1.5">
                      <span className="w-2.5 h-2.5 rounded-full bg-gray-600" /> Bo'sh (4)
                    </span>
                  </div>
                </div>

                <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-2 sm:gap-3">
                  {[
                    { num: 1, seats: 4, status: 'busy', waiter: 'Bobur', amount: '240,000' },
                    { num: 2, seats: 2, status: 'free', waiter: '-', amount: '0' },
                    { num: 3, seats: 2, status: 'busy', waiter: 'Madina', amount: '124,000' },
                    { num: 4, seats: 6, status: 'busy', waiter: 'Bobur', amount: '480,000' },
                    { num: 5, seats: 4, status: 'free', waiter: '-', amount: '0' },
                    { num: 6, seats: 4, status: 'busy', waiter: 'Javohir', amount: '190,000' },
                    { num: 7, seats: 8, status: 'busy', waiter: 'Bobur', amount: '321,000' },
                    { num: 8, seats: 2, status: 'busy', waiter: 'Nilufar', amount: '85,000' },
                    { num: 9, seats: 4, status: 'busy', waiter: 'Madina', amount: '155,000' },
                    { num: 10, seats: 4, status: 'free', waiter: '-', amount: '0' },
                    { num: 11, seats: 6, status: 'busy', waiter: 'Bobur', amount: '290,000' },
                    { num: 12, seats: 6, status: 'busy', waiter: 'Javohir', amount: '364,000' },
                  ].map((table) => (
                    <div
                      key={table.num}
                      className={`p-3 rounded-2xl border text-center transition-all ${
                        table.status === 'busy'
                          ? 'bg-red-500/10 border-red-500/30 text-white'
                          : 'bg-white/[0.02] border-white/10 text-gray-500'
                      }`}
                    >
                      <div className="text-xs font-bold font-mono">Stol #{table.num}</div>
                      <div className="text-[10px] text-gray-400 mt-0.5">{table.seats} kishilik</div>
                      <div className="mt-2 text-[11px] font-semibold text-red-400">
                        {table.status === 'busy' ? table.amount : 'Bo\'sh'}
                      </div>
                    </div>
                  ))}
                </div>
              </motion.div>
            )}

            {activeTab === 'staff' && (
              <motion.div
                key="staff"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ duration: 0.3 }}
                className="space-y-3"
              >
                <div className="flex items-center justify-between text-xs text-gray-400 pb-2 border-b border-white/[0.06]">
                  <span>Bugungi faol smena: 7 nafar xodim</span>
                  <span className="text-red-400 font-medium">Barcha buyurtmalar vaqti: 14 daqiqa o'rtacha</span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {[
                    { name: 'Bobur Mirzayev', role: 'Katta ofitsiant', orders: 48, sales: '9,400,000', rating: 4.9 },
                    { name: 'Madina Umarova', role: 'Ofitsiant', orders: 42, sales: '7,800,000', rating: 4.8 },
                    { name: 'Javohir Karimov', role: 'Ofitsiant', orders: 38, sales: '6,900,000', rating: 4.7 },
                    { name: 'Nilufar Sobirova', role: 'Barista', orders: 56, sales: '4,200,000', rating: 5.0 },
                  ].map((staff, i) => (
                    <div
                      key={i}
                      className="glass-card p-3.5 rounded-xl border border-white/10 flex items-center justify-between"
                    >
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-red-500/10 border border-red-500/30 flex items-center justify-center font-bold text-red-500 text-sm">
                          {staff.name.slice(0, 2).toUpperCase()}
                        </div>
                        <div>
                          <h5 className="text-sm font-semibold text-white">{staff.name}</h5>
                          <p className="text-xs text-gray-400">{staff.role} • ★ {staff.rating}</p>
                        </div>
                      </div>
                      <div className="text-right">
                        <div className="text-xs font-bold text-red-400">{staff.sales} so'm</div>
                        <div className="text-[11px] text-gray-400">{staff.orders} buyurtma yopdi</div>
                      </div>
                    </div>
                  ))}
                </div>
              </motion.div>
            )}

            {activeTab === 'stats' && (
              <motion.div
                key="stats"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ duration: 0.3 }}
                className="grid grid-cols-1 sm:grid-cols-3 gap-4"
              >
                <div className="glass-card p-4 rounded-2xl border border-white/10">
                  <span className="text-xs text-gray-400">Bugungi tushum</span>
                  <div className="text-2xl font-extrabold text-white mt-1">28,450,000 so'm</div>
                  <span className="text-xs text-red-400 font-semibold inline-flex items-center gap-1 mt-2">
                    <TrendingUp className="w-3.5 h-3.5" /> +24% kechagiga nisbatan
                  </span>
                </div>

                <div className="glass-card p-4 rounded-2xl border border-white/10">
                  <span className="text-xs text-gray-400">O'rtacha chek miqdori</span>
                  <div className="text-2xl font-extrabold text-cyan-400 mt-1">185,000 so'm</div>
                  <span className="text-xs text-gray-400 mt-2 block">154 ta yopilgan chek</span>
                </div>

                <div className="glass-card p-4 rounded-2xl border border-white/10">
                  <span className="text-xs text-gray-400">To'lov usullari taqsimoti</span>
                  <div className="mt-2 space-y-1.5 text-xs">
                    <div className="flex justify-between text-gray-300">
                      <span>Click / Payme</span>
                      <span className="font-bold text-red-400">58%</span>
                    </div>
                    <div className="flex justify-between text-gray-300">
                      <span>Bank kartalari</span>
                      <span className="font-bold text-cyan-400">32%</span>
                    </div>
                    <div className="flex justify-between text-gray-300">
                      <span>Naqd pul</span>
                      <span className="font-bold text-gray-400">10%</span>
                    </div>
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        {/* Bottom Status bar */}
        <div className="px-4 sm:px-6 py-3 border-t border-white/[0.08] bg-[#090C16]/80 flex flex-col sm:flex-row items-center justify-between text-xs text-gray-400 gap-2">
          <div className="flex items-center gap-4">
            <span className="flex items-center gap-1.5 text-red-400">
              <CheckCircle2 className="w-3.5 h-3.5" /> Cloud Sync: 0.12s
            </span>
            <span className="hidden sm:inline">•</span>
            <span className="flex items-center gap-1 text-gray-300">
              <Coffee className="w-3.5 h-3.5 text-amber-400" /> ESC/POS Chek printerlari ulangan
            </span>
          </div>

          <div className="flex items-center gap-2">
            <span className="text-gray-400">Zavero Flutter OS v2.4</span>
          </div>
        </div>
      </div>
    </div>
  );
};
