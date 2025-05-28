import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

// Connects to data-controller="analytics"
export default class extends Controller {
  static targets = ["errorTypesChart", "weeklyProgressChart"]

  connect() {
    this.initializeCharts()
  }

  initializeCharts() {
    this.initializeErrorTypesChart()
    this.initializeWeeklyProgressChart()
  }

  initializeErrorTypesChart() {
    if (!this.hasErrorTypesChartTarget) return

    const chartData = JSON.parse(this.errorTypesChartTarget.dataset.chartData || '{}')
    
    if (!chartData.labels || !chartData.values) return

    new Chart(this.errorTypesChartTarget, {
      type: 'pie',
      data: {
        labels: chartData.labels,
        datasets: [{
          data: chartData.values,
          backgroundColor: [
            '#4F46E5', '#10B981', '#F59E0B', '#EF4444',
            '#8B5CF6', '#EC4899', '#6366F1', '#14B8A6'
          ]
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'right'
          }
        }
      }
    })
  }

  initializeWeeklyProgressChart() {
    if (!this.hasWeeklyProgressChartTarget) return

    const chartData = JSON.parse(this.weeklyProgressChartTarget.dataset.chartData || '{}')
    
    if (!chartData.labels || !chartData.values) return

    new Chart(this.weeklyProgressChartTarget, {
      type: 'line',
      data: {
        labels: chartData.labels,
        datasets: [{
          label: 'Errors per Week',
          data: chartData.values,
          borderColor: '#4F46E5',
          backgroundColor: 'rgba(79, 70, 229, 0.1)',
          fill: true,
          tension: 0.3
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: 'Number of Errors'
            }
          },
          x: {
            title: {
              display: true,
              text: 'Week'
            }
          }
        }
      }
    })
  }
}
