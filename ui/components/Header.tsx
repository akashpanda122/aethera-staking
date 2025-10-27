'use client'
import React, { useState } from 'react';
import { usePathname } from 'next/navigation';
import './header.css';
import { WalletButton } from '@/components/WalletButton';

const tabs = [
    {
        id: 0,
        icon: "atheraLogo.png",
        title: 'Aethera',
        path: '/staking'
    }
];

export const Header = () => {
    const pathname = usePathname();
    const [isMenuOpen, setIsMenuOpen] = useState(false);

    return (
        <header className='header'>
            <button 
                className='header-open-btn' 
                onClick={() => setIsMenuOpen(true)}
                aria-label="Open menu"
            >
                <div className="header-open-btn-line" />
                <div className="header-open-btn-line" />
                <div className="header-open-btn-line" />
            </button>

            <div className='header__tabs'>
                {tabs.map(tab => (
                    <div 
                        key={tab.id}
                        className={`header__tabs-item ${pathname === tab.path ? 'active' : ''}`}
                    >
                        <img 
                            src={tab.icon} 
                            className="header__logo" 
                            alt={`${tab.title} logo`}
                        />
                        &nbsp;
                        {tab.title}
                    </div>
                ))}
            </div>

            <WalletButton />

            <div className={`header-menu ${isMenuOpen ? 'open' : ''}`}>
                <div className="header-menu-header">
                    <button 
                        className="header-menu-close"
                        onClick={() => setIsMenuOpen(false)}
                        aria-label="Close menu"
                    >
                        ×
                    </button>
                    <WalletButton />
                </div>

                <div className="header-menu-list">
                    {tabs.map(tab => (
                        <p
                            key={tab.id}
                            className={`header-menu-list-item ${pathname === tab.path ? 'active' : ''}`}
                        >
                            <img 
                                src={tab.icon} 
                                alt={`${tab.title} logo`}
                                className="header__logo"
                            />
                            {tab.title}
                        </p>
                    ))}
                </div>
            </div>
        </header>
    );
};
