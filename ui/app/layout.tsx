import "./globals.css";

import { Geist, Geist_Mono } from "next/font/google";

import type { Metadata } from "next";
import { Toaster } from "sonner";
import { HederaProvider } from "@/components/provider/Hedera";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Aethera",
  description: "A minimal frontend for Hedera smart contract",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased bg-gray-950 text-white`}
      >
        <HederaProvider>
          {children}
          <Toaster
            position="bottom-right"
            theme="dark"
            closeButton
            richColors={false}
            toastOptions={{
              style: {
                background: "#171717",
                color: "white",
                border: "1px solid rgba(75, 85, 99, 0.3)",
                borderRadius: "0.5rem",
                padding: "0.75rem 1rem",
                boxShadow: "0 10px 15px -3px rgba(0, 0, 0, 0.5)",
              },
              className: "toast-container",
            }}
          />
        </HederaProvider>
      </body>
    </html>
  );
}