// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// Register enhanced controllers for improved UX
import PerformanceMonitorController from "./performance_monitor_controller"
import LazyLoadingController from "./lazy_loading_controller"
import ErrorBoundaryController from "./error_boundary_controller"
import AccessibilityController from "./accessibility_controller"

// Register the enhanced controllers
application.register("performance-monitor", PerformanceMonitorController)
application.register("lazy-loading", LazyLoadingController)
application.register("error-boundary", ErrorBoundaryController)
application.register("accessibility", AccessibilityController)
