import React from 'react'

export default function FaqPage() {
  return (
    <div className="min-h-screen w-screen bg-gray-50 relative">
      <img
        src="/favicon.png"
        alt="Promptexto"
        className="absolute top-4 left-4 rounded w-24 h-auto"
      />
      <button
        onClick={() => { window.location.hash = '#/' }}
        className="absolute top-4 right-4 text-sm text-gray-700"
      >
        ← Home
      </button>

      <div className="max-w-3xl mx-auto px-6 py-16">
        <h2 className="text-2xl font-bold text-slate-900 mb-6">FAQ</h2>

        <section className="mb-6">
          <h2 className="text-lg font-semibold text-slate-800 mb-2">How can I use this product?</h2>
          <p className="text-slate-700">
          Promptexto is a tool to help users build better prompts for artificial intelligence. It uses AI to evaluate and grade how effective a given prompt will be.<br /><br />
          To use Promptexto, simply enter a question, request a code change, or describe something you want built. Promptexto will grade your prompt and generate an improved version designed to produce more meaningful and consistent results.
          </p>
        </section>

        <section className="mb-6">
          <h2 className="text-lg font-semibold text-slate-800 mb-2">Why Does this Matter?</h2>
          <p className="text-slate-700">
            Research in prompt engineering shows that the clarity, structure, and specificity of a prompt directly influence the quality of AI responses. Well-crafted prompts help models better understand user intent, reduce ambiguity, and produce more accurate, creative, and consistent results.<br /><br />
            By learning what makes a prompt effective, users not only improve their own outputs but also help train AI systems to align more closely with human goals and reasoning.
          </p>
        </section>

        <section className="mb-6">
          <h2 className="text-lg font-semibold text-slate-800 mb-2">How is the Suggested Prompt Built?</h2>
          <p className="text-slate-700">
            The suggest prompt shows the real value of Promptexto. Using the outputs from the LLM and Empirical judges it builds a prompt that is more likely to produce the desired output.<br /><br />
            The goal of the suggested prompt is to provide the user with something that will more effectively complete the task or answer the question that their original prompt asks for. The user can then easily copy the suggested prompt and use in their desired application.<br /><br />
            Paid users gain access to integration with ChatGPT. With the click of a button, they can send their prompt through ChatGPT, straight from Promptexto.
          </p>
        </section>

        <section className="mb-6">
          <h2 className="text-lg font-semibold text-slate-800 mb-2">What is the LLM judge?</h2>
          <p className="text-slate-700">
            The LLM judge rates prompt quality based on clarity, completeness, feasibility, and format guidance.
            It provides a numeric score and brief reasons to help you understand strengths and gaps.
          </p>
        </section>

        <section className="mb-6">
          <h2 className="text-lg font-semibold text-slate-800 mb-2">What is the Empirical Judge?</h2>
          <p className="text-slate-700">
            The empirical judge runs your prompt twice through gpt-4o-mini and evaluates the outputs for structure, substance, and most importantly, consistency. Constistency shows the prompt quality, because it directly reflects the clarity of the instructions given.<br /><br />
            When given clear instructions, AI will output two very similar results. When instrucitons are unclear, AI will likely output two very different results.
          </p>
        </section>
      </div>

      <div className="fixed bottom-0 left-0 right-0 bg-blue-600 text-white">
      <div className="max-w-5xl mx-auto py-3 flex items-center justify-center gap-10">
        <button
          className="font-medium"
          style={{ color: '#ffffff' }}
          onClick={() => { window.location.hash = '#/faq' }}
        >
          FAQ
        </button>
        <a
          className="font-medium"
          style={{ color: '#ffffff' }}
          href="mailto:promptexto@gmail.com"
        >
          Contact Us
        </a>

        <a
          className="font-medium"
          style={{ color: '#ffffff' }}
          href="mailto:promptexto@gmail.com"
        >
          Report a Bug
        </a>
      </div>
    </div>
    </div>
  )
}


