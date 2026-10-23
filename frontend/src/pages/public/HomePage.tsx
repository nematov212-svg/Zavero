import React from 'react';
import { HeroSection } from '../../sections/HeroSection';
import { LiveStatsSection } from '../../sections/LiveStatsSection';
import { PartnerCafesSection } from '../../sections/PartnerCafesSection';
import { FeaturesSection } from '../../sections/FeaturesSection';
import { EmployeeManagementSection } from '../../sections/EmployeeManagementSection';
import { PricingSection } from '../../sections/PricingSection';
import { LeadFormSection } from '../../sections/LeadFormSection';
import { FaqSection } from '../../sections/FaqSection';
import { CtaSection } from '../../sections/CtaSection';

export const HomePage: React.FC = () => {
  return (
    <div>
      <HeroSection />
      <LiveStatsSection />
      <PartnerCafesSection />
      <FeaturesSection />
      <EmployeeManagementSection />
      <PricingSection />
      <LeadFormSection />
      <FaqSection />
      <CtaSection />
    </div>
  );
};
