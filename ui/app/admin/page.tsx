import { Metadata } from "next";
import { AdminBody } from "@/components/AdminBody";
import { AdminHeader } from "@/components/AdminHeader";

export const metadata: Metadata = {
  title: "Admin Dashboard",
  description: "Admin dashboard for managing Solana staking program",
};

export default function AdminPage() {
  return (
    <div className="">
        <AdminHeader/>
        <AdminBody/>
  </div>
  );
} 