'use client';
import { useState, useEffect } from 'react';
import Navbar from '@/components/Navbar';
import Hero from '@/components/Hero';
import Integrations from '@/components/Integrations';
import Features from '@/components/Features';
import HowItWorks from '@/components/HowItWorks';
import Architecture from '@/components/Architecture';
import Pricing from '@/components/Pricing';
import CTA from '@/components/CTA';
import Footer from '@/components/Footer';
import LeadModal from '@/components/LeadModal';
import AgentExchangePromo from '@/components/AgentExchangePromo';
import AgentforceSection from '@/components/AgentforceSection';

export default function Home() {
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedPlan, setSelectedPlan] = useState('');

  const openModal = (plan = '') => {
    setSelectedPlan(plan);
    setModalOpen(true);
  };

  const closeModal = () => {
    setModalOpen(false);
  };

  useEffect(() => {
    // Simple intersection observer for fade-up animations
    const observerOptions = {
      root: null,
      rootMargin: '0px',
      threshold: 0.1
    };

    const observer = new IntersectionObserver((entries, observer) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('aos-animate');
          observer.unobserve(entry.target);
        }
      });
    }, observerOptions);

    const elements = document.querySelectorAll('[data-aos]');
    elements.forEach(el => {
      // Setup initial state
      el.classList.add('aos-init');
      observer.observe(el);
    });

    return () => observer.disconnect();
  }, []);

  return (
    <>
      <Navbar />
      <main>
        <Hero />
        <AgentExchangePromo onOpenModal={openModal} />
        <Integrations />
        <Features />
        <HowItWorks />
        <Architecture />
        <AgentforceSection />
        <Pricing onOpenModal={openModal} />
        <CTA onOpenModal={openModal} />
      </main>
      <Footer />
      <LeadModal isOpen={modalOpen} onClose={closeModal} plan={selectedPlan} />
    </>
  );
}
