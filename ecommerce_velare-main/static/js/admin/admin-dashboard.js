// Admin Dashboard - Sales Overview Chart
let salesChart = null;

// Initialize chart when page loads
document.addEventListener('DOMContentLoaded', function() {
    loadSalesChart('7days');
    
    // Add event listener to period filter
    const periodFilter = document.getElementById('salesPeriodFilter');
    const dateRangeInputs = document.getElementById('dateRangeInputs');
    const applyDateBtn = document.getElementById('applyDateRange');
    
    if (periodFilter) {
        periodFilter.addEventListener('change', function() {
            if (this.value === 'custom') {
                // Show date range inputs
                if (dateRangeInputs) {
                    dateRangeInputs.style.display = 'flex';
                }
            } else {
                // Hide date range inputs and load chart
                if (dateRangeInputs) {
                    dateRangeInputs.style.display = 'none';
                }
                loadSalesChart(this.value);
            }
        });
    }
    
    // Add event listener to apply date range button
    if (applyDateBtn) {
        applyDateBtn.addEventListener('click', function() {
            const startDate = document.getElementById('chartStartDate').value;
            const endDate = document.getElementById('chartEndDate').value;
            
            if (!startDate || !endDate) {
                alert('Please select both start and end dates');
                return;
            }
            
            if (new Date(startDate) > new Date(endDate)) {
                alert('Start date must be before end date');
                return;
            }
            
            loadSalesChart('custom', startDate, endDate);
        });
    }
});

// Load sales chart data
async function loadSalesChart(period, startDate = null, endDate = null) {
    try {
        let url = `/admin/dashboard/sales-data?period=${period}`;
        
        // Add date parameters for custom range
        if (period === 'custom' && startDate && endDate) {
            url += `&start_date=${startDate}&end_date=${endDate}`;
        }
        
        const response = await fetch(url);
        
        if (!response.ok) {
            throw new Error('Failed to fetch sales data');
        }
        
        const data = await response.json();
        
        // Destroy existing chart if it exists
        if (salesChart) {
            salesChart.destroy();
        }
        
        // Create new chart
        const ctx = document.getElementById('salesChart').getContext('2d');
        
        salesChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: data.labels,
                datasets: [
                    {
                        label: 'Sales (₱)',
                        data: data.sales,
                        borderColor: '#bfa14a',
                        backgroundColor: 'rgba(191, 161, 74, 0.1)',
                        borderWidth: 2,
                        fill: true,
                        tension: 0.4,
                        pointRadius: 4,
                        pointHoverRadius: 6,
                        pointBackgroundColor: '#bfa14a',
                        pointBorderColor: '#fff',
                        pointBorderWidth: 2,
                        yAxisID: 'y'
                    },
                    {
                        label: 'Orders',
                        data: data.orders,
                        borderColor: '#2d7a3e',
                        backgroundColor: 'rgba(45, 122, 62, 0.1)',
                        borderWidth: 2,
                        fill: true,
                        tension: 0.4,
                        pointRadius: 4,
                        pointHoverRadius: 6,
                        pointBackgroundColor: '#2d7a3e',
                        pointBorderColor: '#fff',
                        pointBorderWidth: 2,
                        yAxisID: 'y1'
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                aspectRatio: 2.5,
                interaction: {
                    mode: 'index',
                    intersect: false,
                },
                plugins: {
                    legend: {
                        display: true,
                        position: 'top',
                        labels: {
                            font: {
                                family: "'Montserrat', sans-serif",
                                size: 12,
                                weight: '500'
                            },
                            color: '#181818',
                            padding: 15,
                            usePointStyle: true,
                            pointStyle: 'circle'
                        }
                    },
                    tooltip: {
                        backgroundColor: 'rgba(24, 24, 24, 0.95)',
                        titleFont: {
                            family: "'Playfair Display', serif",
                            size: 14,
                            weight: '600'
                        },
                        bodyFont: {
                            family: "'Montserrat', sans-serif",
                            size: 13
                        },
                        padding: 12,
                        cornerRadius: 0,
                        displayColors: true,
                        callbacks: {
                            label: function(context) {
                                let label = context.dataset.label || '';
                                if (label) {
                                    label += ': ';
                                }
                                if (context.parsed.y !== null) {
                                    if (context.datasetIndex === 0) {
                                        // Sales - format as currency
                                        label += '₱' + context.parsed.y.toLocaleString('en-PH', {
                                            minimumFractionDigits: 2,
                                            maximumFractionDigits: 2
                                        });
                                    } else {
                                        // Orders - format as number
                                        label += context.parsed.y.toLocaleString('en-PH');
                                    }
                                }
                                return label;
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        grid: {
                            display: false
                        },
                        ticks: {
                            font: {
                                family: "'Montserrat', sans-serif",
                                size: 11
                            },
                            color: '#666',
                            maxRotation: 45,
                            minRotation: 0
                        }
                    },
                    y: {
                        type: 'linear',
                        display: true,
                        position: 'left',
                        grid: {
                            color: 'rgba(224, 215, 198, 0.3)',
                            drawBorder: false
                        },
                        ticks: {
                            font: {
                                family: "'Montserrat', sans-serif",
                                size: 11
                            },
                            color: '#666',
                            callback: function(value) {
                                return '₱' + value.toLocaleString('en-PH');
                            }
                        },
                        title: {
                            display: true,
                            text: 'Sales (₱)',
                            font: {
                                family: "'Playfair Display', serif",
                                size: 12,
                                weight: '600'
                            },
                            color: '#bfa14a'
                        }
                    },
                    y1: {
                        type: 'linear',
                        display: true,
                        position: 'right',
                        grid: {
                            drawOnChartArea: false,
                        },
                        ticks: {
                            font: {
                                family: "'Montserrat', sans-serif",
                                size: 11
                            },
                            color: '#666',
                            callback: function(value) {
                                return value.toLocaleString('en-PH');
                            }
                        },
                        title: {
                            display: true,
                            text: 'Orders',
                            font: {
                                family: "'Playfair Display', serif",
                                size: 12,
                                weight: '600'
                            },
                            color: '#2d7a3e'
                        }
                    }
                }
            }
        });
        
    } catch (error) {
        console.error('Error loading sales chart:', error);
        // Show error message in chart area
        const chartContainer = document.querySelector('.chart-container');
        if (chartContainer) {
            chartContainer.innerHTML = `
                <div style="height: 300px; display: flex; align-items: center; justify-content: center; color: #999;">
                    <i class="bi bi-exclamation-triangle" style="font-size: 2rem; margin-right: 10px;"></i>
                    <span>Failed to load sales data</span>
                </div>
            `;
        }
    }
}
