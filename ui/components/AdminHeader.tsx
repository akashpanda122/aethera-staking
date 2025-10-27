'use client'
import React, { useRef, useState } from 'react';
import './adminHeader.css';
import { WalletButton } from '@/components/WalletButton';
import { useRouter } from 'next/navigation';
import { Home, Settings } from 'lucide-react';
import { usePathname } from 'next/navigation';

interface Tab {
    id: number;
    title: string;
    icon: React.ReactNode;
    route: string;
}

export const AdminHeader = () => {
    const [opened, setOpened] = useState(false);
    const refMenu = useRef(null);
    const router = useRouter();
    const pathname = usePathname();

    const tabs: Tab[] = [
        {
            id: 1,
            title: "Main",
            icon: <Home size={20} />,
            route: "/"
        },
        {
            id: 2,
            title: "Admin",
            icon: <Settings size={20} />,
            route: "/admin"
        }
    ];

    return (
        <header className='header'>
            <button className='header-open-btn' onClick={() => setOpened(true)}>
                <div className="header-open-btn-line" />
                <div className="header-open-btn-line" />
                <div className="header-open-btn-line" />
            </button>
            <div className='header__tabs'>
                
                {tabs.map(tab => (
                    <div 
                    className={`header__tabs-item ${pathname === tab.route ? 'active' : ''}`}

                         key={tab.id} 
                         onClick={() => router.push(tab.route)}>
                        {tab.icon} &nbsp;
                        {tab.title}
                    </div>
                ))}
            </div>
            <WalletButton/>

            <div className={`header-menu ${opened && 'open'}`} ref={refMenu}>
              
                <WalletButton/>
                <div className="header-menu-list">
                        {tabs.map(tab => (
                            <p
                            key={tab.id}
                            className={`header-menu-list-item ${tab.route === pathname && 'active'}`}>
                                {tab.icon}
                                {tab.title}
                            </p>
                        ))}
                </div>
            </div>
        </header>
    )
}
