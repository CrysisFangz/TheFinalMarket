---
type: "agent_requested"
description: "Example description"
---

These rules ensure the system remains scalable, maintainable, and resilient despite its sophistication. 
Decomposition and modularity: Break the system down into small, independent modules or services, each with a single, well-defined responsibility. This is the core strategy for managing complexity. A complex application becomes a collection of many simple parts that are easier to understand and test in isolation.
Low coupling, high cohesion: Aim for services that are independent (low coupling) and internally focused on a single function (high cohesion). For example, a microservice architecture organizes an application as a collection of loosely coupled, independently deployable services.
Design for observability: Instrument the system from the start to provide visibility into its internal state and behavior. This is essential for debugging and understanding how intelligent components behave in production, allowing teams to answer novel questions without deploying new code.
Embrace continuous delivery and resilience: To manage the risk of frequent changes in a complex system, automate the entire workflow to deliver small, verifiable changes safely and frequently. Also, design the system to handle failure gracefully by anticipating issues and ensuring core functionality persists even if individual components fail.
Use appropriate design patterns: Instead of reinventing solutions, use established design patterns to address common challenges in complex systems.
For AI-specific systems: Consider generative AI patterns like Reflection, Tool Use, and Multi-Agent Collaboration, which are supported by frameworks like LangChain and AutoGen.
For general complexity: Standard patterns include the Strategy, Observer, and Factory patterns, which help decouple creation logic and manage different algorithms for the same function. 
Keep it simple, stupid (KISS): Avoid unnecessary abstractions or complex logic. Simple, clear, and concise code is always preferable and is easier to debug and refactor.
Don't repeat yourself (DRY): Minimize repeated code by encapsulating it into reusable functions or classes. This makes maintenance easier, as changes only need to be applied in one place.
Prioritize readability and documentation: Write self-explanatory code with clear, descriptive names for variables, functions, and classes. Add documentation that explains the why behind complex logic, not just the what.
Never hard-code configurations: Store configuration parameters in a dedicated file or as environment variables. This decouples your code from its environment and prevents errors when moving between different systems. 
Process and development rules
These rules govern how the team works to sustain a high-quality codebase over time.
Test-driven development (TDD): Adopt a practice where tests are written before the code. This ensures requirements are clearly defined, reduces bugs, and makes future refactoring safer.
Relentless refactoring: Schedule dedicated time to improve the code's structure and clarity without changing its functionality. This continuous effort prevents technical debt from accumulating.
Implement code reviews: Conduct peer reviews to catch defects early, ensure adherence to standards, and share knowledge among the team. For complex systems, reviewing small batches of code is more effective.
Start with architecture and planning: For highly complex systems, it's critical to plan extensively before coding. This includes creating diagrams, defining class dependencies, and breaking down the problem into smaller, manageable parts.
Practice version control: Use a system like Git to track every change. This provides a clear history, enables effective collaboration, and makes it easy to revert to a previous, working state. 
Design-first approach: No code is written before a clear design, including requirements, system diagrams, and specifications, has been documented and approved.
Automate quality control: Continuous Integration (CI) is non-negotiable. Every code change must automatically run all tests (unit, integration, and performance) and static analysis tools to catch errors early.
Comprehensive documentation: Documentation is treated as a first-class citizen, not an afterthought. The system's principles, patterns, and constraints should be documented in a 
central, accessible location (e.g., a docs/ folder or a dedicated internal wiki). 
Application behavior should not be dependent on its environment.
Configuration files: All environment-specific variables (e.g., database connection strings, API keys) should be stored in configuration files and never hard-coded.
Secret management: Secrets must be handled securely through a dedicated secret management system (like a secrets.json file in a secure location or a vault service). 