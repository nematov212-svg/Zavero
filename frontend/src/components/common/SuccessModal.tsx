import React, { useEffect } from 'react';
import confetti from 'canvas-confetti';
import { motion, AnimatePresence } from 'framer-motion';
import { CheckCircle2, PhoneCall, Sparkles } from 'lucide-react';
import { Button } from './Button';

interface SuccessModalProps {
  isOpen: boolean;
  onClose: () => void;
  leadName?: string;
  businessName?: string;
}

export const SuccessModal: React.FC<SuccessModalProps> = ({
  isOpen,
  onClose,
  leadName,
  businessName,
}) => {
  useEffect(() => {
    if (isOpen) {
      try {
        confetti({
          particleCount: 80,
          spread: 70,
          origin: { y: 0.6 },
          colors: ['#10B981', '#06B6D4', '#6366F1', '#F59E0B'],
        });
      } catch (e) {
        // ignore if canvas not supported
      }
    }
  }, [isOpen]);

  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6">
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 bg-black/80 backdrop-blur-md"
          />

          {/* Card */}
          <motion.div
            initial={{ opacity: 0, scale: 0.9, y: 30 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.9, y: 30 }}
            transition={{ type: 'spring', damping: 25, stiffness: 300 }}
            className="relative w-full max-w-md glass-panel bg-[#0E1322] border border-emerald-500/30 rounded-3xl p-8 text-center shadow-2xl z-10 overflow-hidden"
          >
            {/* Top glowing ambient effect */}
            <div className="absolute -top-24 left-1/2 -translate-x-1/2 w-64 h-64 bg-emerald-500/20 rounded-full blur-3xl pointer-events-none" />

            <div className="relative mb-6">
              <div className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 mb-2">
                <CheckCircle2 className="w-10 h-10 animate-bounce" />
              </div>
              <div className="absolute -top-1 -right-1 flex items-center justify-center w-7 h-7 rounded-full bg-amber-400 text-black">
                <Sparkles className="w-4 h-4" />
              </div>
            </div>

            <h3 className="text-2xl font-extrabold text-white mb-2 tracking-tight">
              Rahmat! Tez orada siz bilan bog'lanamiz.
            </h3>

            <p className="text-gray-300 text-sm mb-6 leading-relaxed">
              {leadName ? <span className="font-semibold text-white">{leadName}</span> : 'Hurmatli mijoz'}
              {businessName ? ` (${businessName})` : ''}, so'rovingiz Zavero Director Panelga real vaqtda yetkazildi. Mutaxassisimiz tez orada sizga qo'ng'iroq qiladi!
            </p>

            <div className="p-3.5 rounded-xl bg-white/[0.03] border border-white/10 mb-6 text-xs text-emerald-400/90 flex items-center justify-center gap-2">
              <PhoneCall className="w-4 h-4 shrink-0 text-emerald-400" />
              <span>Ish vaqti: Har kuni 09:00 - 21:00</span>
            </div>

            <Button
              variant="primary"
              size="lg"
              className="w-full justify-center"
              onClick={onClose}
            >
              Tushunarli, rahmat!
            </Button>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
};
