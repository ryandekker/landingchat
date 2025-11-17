/**
 * Email capture component
 */

import { useState, FormEvent } from 'react';
import { isValidEmail } from '@landingchat/shared';

interface EmailCaptureProps {
  onSubmit: (email: string) => void;
  isSubmitting: boolean;
  currentEmail?: string;
}

export function EmailCapture({ onSubmit, isSubmitting, currentEmail }: EmailCaptureProps) {
  const [email, setEmail] = useState('');
  const [submitted, setSubmitted] = useState(!!currentEmail);

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();

    if (isValidEmail(email) && !isSubmitting) {
      onSubmit(email);
      setSubmitted(true);
    }
  };

  if (submitted || currentEmail) {
    return (
      <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
        <p className="text-sm text-green-800">
          Email saved: {currentEmail || email}
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <h3 className="font-semibold text-sm">Don't lose your progress</h3>
      <p className="text-xs text-gray-600">
        Add your email and we'll send your summary and recommendations here.
      </p>
      <form onSubmit={handleSubmit} className="space-y-2">
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="your@email.com"
          disabled={isSubmitting}
          className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500 disabled:bg-gray-100"
        />
        <button
          type="submit"
          disabled={isSubmitting || !isValidEmail(email)}
          className="w-full px-4 py-2 text-sm bg-primary-600 text-white rounded-lg hover:bg-primary-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
        >
          {isSubmitting ? 'Saving...' : 'Save Email'}
        </button>
      </form>
    </div>
  );
}
