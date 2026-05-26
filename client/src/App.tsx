import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { QueryClientProvider } from "@tanstack/react-query";
import { queryClient } from "@/lib/queryClient";
import RootLayout from "@/routes/_layout";
import HomePage from "@/routes/home";
import LoginPage from "@/routes/login";
import SignupPage from "@/routes/signup";
import { SessionBootstrap } from "@/components/SessionBootstrap";
import { ProtectedRoute } from "@/components/ProtectedRoute";

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter basename="/ui">
        <SessionBootstrap />
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/signup" element={<SignupPage />} />
          <Route element={<RootLayout />}>
            <Route
              index
              element={
                <ProtectedRoute>
                  <HomePage />
                </ProtectedRoute>
              }
            />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  );
}
