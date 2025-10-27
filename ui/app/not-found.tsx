'use client'
import React from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';

export default function NotFound() {
    const router = useRouter();

    return (
        <div className="min-h-screen flex items-center justify-center bg-gray-950">
            <div className="text-center px-4">
                <h1 className="text-6xl font-bold text-white mb-4">404</h1>
                <h2 className="text-2xl font-semibold text-gray-300 mb-6">Page Not Found</h2>
                <p className="text-gray-400 mb-8">
                    The page you&apos;re looking for doesn&apos;t exist or has been moved.
                </p>
                <div className="space-x-4">
                    <button
                        onClick={() => router.back()}
                        className="px-6 py-2 bg-gray-800 text-white rounded-lg hover:bg-gray-700 transition-colors"
                    >
                        Go Back
                    </button>
                    <Link
                        href="/"
                        className="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-500 transition-colors inline-block"
                    >
                        Go Home
                    </Link>
                </div>
            </div>
        </div>
    );
}