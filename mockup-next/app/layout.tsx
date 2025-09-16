import "./globals.css";
export const metadata = {
  title: "AI Trip Planner — Mockup",
  description: "Next.js mock UI for trip planner",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
