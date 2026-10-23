import React from 'react';
import { Outlet } from 'react-router-dom';
import { Navbar } from '../components/common/Navbar';
import { Footer } from '../components/common/Footer';

export const PublicLayout: React.FC = () => {
  return (
    <div className="flex flex-col min-h-screen bg-white dark:bg-[#080A10] text-gray-900 dark:text-[#F3F4F6] transition-colors duration-300">
      <Navbar />
      <main className="flex-1">
        <Outlet />
      </main>
      <Footer />
    </div>
  );
};
