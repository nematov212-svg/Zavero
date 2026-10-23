import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Send, Phone, User, Store, MapPin, MessageSquare, AlertCircle, CheckCircle2 } from 'lucide-react';
import { Button } from '../components/common/Button';
import { SuccessModal } from '../components/common/SuccessModal';
import { publicApi } from '../api/publicApi';

export const LeadFormSection: React.FC = () => {
  const [formData, setFormData] = useState({
    name: '',
    phone: '+998 ',
    businessName: '',
    city: 'Toshkent',
    message: '',
  });

  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSuccessModalOpen, setIsSuccessModalOpen] = useState(false);
  const [submittedLeadInfo, setSubmittedLeadInfo] = useState<{ name: string; businessName: string }>({
    name: '',
    businessName: '',
  });

  const validate = () => {
    const newErrors: Record<string, string> = {};

    if (!formData.name.trim() || formData.name.trim().length < 2) {
      newErrors.name = 'Iltimos, ismingizni to\'liq kiriting (kamida 2 belgi)';
    }

    const cleanPhone = formData.phone.replace(/\s+/g, '');
    if (!cleanPhone || cleanPhone.length < 9 || !cleanPhone.startsWith('+998')) {
      newErrors.phone = 'Telefon raqamni +998 90 123 45 67 formatida kiriting';
    }

    if (!formData.businessName.trim() || formData.businessName.trim().length < 2) {
      newErrors.businessName = 'Cafe yoki restoraningiz nomini kiriting';
    }

    if (!formData.city.trim()) {
      newErrors.city = 'Shaharingizni kiriting';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!validate()) return;

    setIsSubmitting(true);
    setErrors({});

    try {
      const response = await publicApi.createLead({
        name: formData.name.trim(),
        phone: formData.phone.trim(),
        businessName: formData.businessName.trim(),
        city: formData.city.trim(),
        message: formData.message.trim() || undefined,
      });

      if (response.success) {
        setSubmittedLeadInfo({
          name: formData.name,
          businessName: formData.businessName,
        });
        setIsSuccessModalOpen(true);
        // Reset form
        setFormData({
          name: '',
          phone: '+998 ',
          businessName: '',
          city: 'Toshkent',
          message: '',
        });
      }
    } catch (err: any) {
      setErrors({
        submit: err.message || 'Xatolik yuz berdi. Iltimos, qayta urinib ko\'ring.',
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <section id="contact-form" className="relative py-16 sm:py-24 md:py-28 bg-white dark:bg-[#080A10] overflow-hidden transition-colors">
      {/* Background radial glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[700px] h-[500px] bg-red-500/10 rounded-full blur-[140px] pointer-events-none" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 lg:gap-12 items-center">
          {/* Left Column: Information */}
          <div className="lg:col-span-5 space-y-4 sm:space-y-6">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-xs font-bold">
              <Store className="w-3.5 h-3.5" />
              <span>Zavero Hamkorlik Dasturi</span>
            </div>

            <h2 className="text-2xl sm:text-4xl lg:text-5xl font-black text-gray-900 dark:text-white tracking-tight leading-tight">
              Zavero haqida ma'lumot olish
            </h2>

            <p className="text-gray-600 dark:text-gray-300 text-sm sm:text-base leading-relaxed">
              Formani to'ldiring. Zavero mutaxassisi 15 daqiqa ichida siz bilan bog'lanib, restoraningiz uchun mos tarif va bepul demo taqdimotini tashkil qiladi.
            </p>

            <div className="p-4 sm:p-6 rounded-2xl glass-panel border border-gray-200 dark:border-white/10 space-y-3 sm:space-y-4 shadow-sm">
              <h4 className="text-gray-900 dark:text-white font-bold text-sm">Zavero bilan nimalarga ega bo'lasiz?</h4>
              <ul className="space-y-2 text-xs text-gray-600 dark:text-gray-300">
                <li className="flex items-center gap-2">
                  <CheckCircle2 className="w-4 h-4 text-red-500 shrink-0" />
                  <span>14 kunlik to'liq bepul sinov davri</span>
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle2 className="w-4 h-4 text-red-500 shrink-0" />
                  <span>Joyiga chiqib bepul o'rnatish va printerlarni ulash</span>
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle2 className="w-4 h-4 text-red-500 shrink-0" />
                  <span>Ofitsiant va kassirlarni o'qitish</span>
                </li>
                <li className="flex items-center gap-2">
                  <CheckCircle2 className="w-4 h-4 text-red-500 shrink-0" />
                  <span>24/7 uzluksiz texnik yordam</span>
                </li>
              </ul>
            </div>
          </div>

          {/* Right Column: Active Form */}
          <div className="lg:col-span-7">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5 }}
              className="glass-panel p-5 sm:p-8 md:p-10 rounded-2xl sm:rounded-3xl border border-gray-200 dark:border-white/10 bg-white/95 dark:bg-[#0E1322]/95 shadow-xl relative"
            >
              <h3 className="text-xl sm:text-2xl font-bold text-gray-900 dark:text-white mb-1 sm:mb-2">Bog'lanish uchun ariza</h3>
              <p className="text-xs text-gray-500 dark:text-gray-400 mb-6 sm:mb-8">Ma'lumotlaringiz xavfsiz saqlanadi va uchinchi shaxslarga berilmaydi.</p>

              {errors.submit && (
                <div className="mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/30 flex items-center gap-3 text-red-600 dark:text-red-400 text-xs">
                  <AlertCircle className="w-4 h-4 shrink-0" />
                  <span>{errors.submit}</span>
                </div>
              )}

              <form onSubmit={handleSubmit} className="space-y-5">
                {/* Ism */}
                <div>
                  <label className="block text-xs font-semibold text-gray-700 dark:text-gray-300 mb-2">
                    Ismingiz <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <User className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                    <input
                      type="text"
                      placeholder="Masalan: Azizbek"
                      value={formData.name}
                      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                      className={`w-full glass-input pl-10 pr-4 py-3 rounded-xl text-sm ${errors.name ? 'border-red-500/50' : ''
                        }`}
                    />
                  </div>
                  {errors.name && <p className="text-[11px] text-red-500 mt-1">{errors.name}</p>}
                </div>

                {/* Telefon & Cafe Nomi Grid */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
                  <div>
                    <label className="block text-xs font-semibold text-gray-700 dark:text-gray-300 mb-2">
                      Telefon raqamingiz <span className="text-red-500">*</span>
                    </label>
                    <div className="relative">
                      <Phone className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                      <input
                        type="text"
                        placeholder="+998 90 123 45 67"
                        value={formData.phone}
                        onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                        className={`w-full glass-input pl-10 pr-4 py-3 rounded-xl text-sm font-mono ${errors.phone ? 'border-red-500/50' : ''
                          }`}
                      />
                    </div>
                    {errors.phone && <p className="text-[11px] text-red-500 mt-1">{errors.phone}</p>}
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-gray-700 dark:text-gray-300 mb-2">
                      Cafe / Restaurant nomi <span className="text-red-500">*</span>
                    </label>
                    <div className="relative">
                      <Store className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                      <input
                        type="text"
                        placeholder="Masalan: Family Cafe"
                        value={formData.businessName}
                        onChange={(e) => setFormData({ ...formData, businessName: e.target.value })}
                        className={`w-full glass-input pl-10 pr-4 py-3 rounded-xl text-sm ${errors.businessName ? 'border-red-500/50' : ''
                          }`}
                      />
                    </div>
                    {errors.businessName && <p className="text-[11px] text-red-500 mt-1">{errors.businessName}</p>}
                  </div>
                </div>

                {/* Shahar */}
                <div>
                  <label className="block text-xs font-semibold text-gray-700 dark:text-gray-300 mb-2">
                    Shahar / Hudud <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <MapPin className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                    <input
                      type="text"
                      placeholder="Masalan: Toshkent, Samarqand, Farg'ona..."
                      value={formData.city}
                      onChange={(e) => setFormData({ ...formData, city: e.target.value })}
                      className={`w-full glass-input pl-10 pr-4 py-3 rounded-xl text-sm ${errors.city ? 'border-red-500/50' : ''
                        }`}
                    />
                  </div>
                  {errors.city && <p className="text-[11px] text-red-500 mt-1">{errors.city}</p>}
                </div>

                {/* Izoh */}
                <div>
                  <label className="block text-xs font-semibold text-gray-700 dark:text-gray-300 mb-2">
                    Qo'shimcha izoh yoki savollaringiz
                  </label>
                  <div className="relative">
                    <MessageSquare className="absolute left-3.5 top-3.5 w-4 h-4 text-gray-400" />
                    <textarea
                      rows={3}
                      placeholder="Stollar soni, filiallar, qiziqtirgan savollar..."
                      value={formData.message}
                      onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                      className="w-full glass-input pl-10 pr-4 py-3 rounded-xl text-sm resize-none"
                    />
                  </div>
                </div>

                <Button
                  type="submit"
                  variant="primary"
                  size="lg"
                  isLoading={isSubmitting}
                  rightIcon={<Send className="w-4 h-4" />}
                  className="w-full justify-center py-4 text-base mt-2"
                >
                  Bog'lanish
                </Button>
              </form>
            </motion.div>
          </div>
        </div>
      </div>

      {/* Success Modal with Confetti */}
      <SuccessModal
        isOpen={isSuccessModalOpen}
        onClose={() => setIsSuccessModalOpen(false)}
        leadName={submittedLeadInfo.name}
        businessName={submittedLeadInfo.businessName}
      />
    </section>
  );
};
