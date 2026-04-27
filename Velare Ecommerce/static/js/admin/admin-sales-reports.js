// Admin Sales Reports JavaScript

// Initialize charts when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
	initializeCategoryChart();
	initializeSellerChart();
	initializeTrendChart();
	initializeFilters();
	initializeExportButtons();
	initializeSearch();
	initializeViewDetailsButtons();
});

// Category Sales Chart
function initializeCategoryChart() {
	const ctx = document.getElementById('categoryChart');
	
	// Extract data from window.salesData
	const categoryLabels = window.salesData.categories.map(cat => cat.category);
	const categoryData = window.salesData.categories.map(cat => cat.total_sales);
	
	const categoryChart = new Chart(ctx, {
		type: 'pie',
		data: {
			labels: categoryLabels.length > 0 ? categoryLabels : ['No Data'],
			datasets: [{
				data: categoryData.length > 0 ? categoryData : [1],
				backgroundColor: [
					'#bfa14a',
					'#D3BD9B',
					'#e0d7c6',
					'#8b7355',
					'#c9b896',
					'#a89080',
					'#d4c4b0',
					'#9b8669'
				],
				borderWidth: 2,
				borderColor: '#fff'
			}]
		},
		options: {
			responsive: true,
			maintainAspectRatio: false,
			plugins: {
				legend: {
					position: 'bottom',
					labels: {
						font: {
							family: 'Montserrat',
							size: 11
						},
						padding: 15,
						usePointStyle: true
					}
				},
				tooltip: {
					callbacks: {
						label: function(context) {
							const label = context.label || '';
							const value = context.parsed || 0;
							const total = context.dataset.data.reduce((a, b) => a + b, 0);
							const percentage = ((value / total) * 100).toFixed(1);
							return `${label}: ₱${value.toLocaleString()} (${percentage}%)`;
						}
					}
				}
			}
		}
	});

	// Chart type selector
	const selector = ctx.closest('.chart-card').querySelector('.chart-type-selector');
	if (selector) {
		selector.addEventListener('change', function() {
			categoryChart.config.type = this.value;
			categoryChart.update();
		});
	}
}

// Top Sellers Chart
function initializeSellerChart() {
	const ctx = document.getElementById('sellerChart');
	if (!ctx) return;

	// Extract data from window.salesData
	const sellerLabels = window.salesData.topSellers.map(seller => seller.store_name);
	const sellerData = window.salesData.topSellers.map(seller => seller.total_sales);

	const sellerChart = new Chart(ctx, {
		type: 'bar',
		data: {
			labels: sellerLabels.length > 0 ? sellerLabels : ['No Data'],
			datasets: [{
				label: 'Sales (₱)',
				data: sellerData.length > 0 ? sellerData : [0],
				backgroundColor: '#bfa14a',
				borderColor: '#8b7355',
				borderWidth: 1
			}]
		},
		options: {
			responsive: true,
			maintainAspectRatio: false,
			indexAxis: 'y',
			plugins: {
				legend: {
					display: false
				},
				tooltip: {
					callbacks: {
						label: function(context) {
							return `Sales: ₱${context.parsed.x.toLocaleString()}`;
						}
					}
				}
			},
			scales: {
				x: {
					beginAtZero: true,
					ticks: {
						callback: function(value) {
							return '₱' + (value / 1000) + 'K';
						},
						font: {
							family: 'Montserrat',
							size: 10
						}
					},
					grid: {
						color: '#f0f0f0'
					}
				},
				y: {
					ticks: {
						font: {
							family: 'Montserrat',
							size: 11
						}
					},
					grid: {
						display: false
					}
				}
			}
		}
	});

	// Chart type selector
	const selector = ctx.closest('.chart-card').querySelector('.chart-type-selector');
	if (selector) {
		selector.addEventListener('change', function() {
			if (this.value === 'pie') {
				sellerChart.config.type = 'pie';
				sellerChart.options.indexAxis = 'x';
			} else {
				sellerChart.config.type = 'bar';
				sellerChart.options.indexAxis = 'y';
			}
			sellerChart.update();
		});
	}
}

// Sales Trend Chart
function initializeTrendChart() {
	const ctx = document.getElementById('trendChart');
	if (!ctx) return;

	let currentPeriod = 'daily';
	
	// Extract data from window.salesData
	const trendLabels = window.salesData.salesTrend.map(trend => trend.date);
	const trendData = window.salesData.salesTrend.map(trend => trend.sales);

	const dailyData = {
		labels: trendLabels.length > 0 ? trendLabels : ['No Data'],
		data: trendData.length > 0 ? trendData : [0]
	};

	const weeklyData = {
		labels: ['Week 35', 'Week 36', 'Week 37', 'Week 38', 'Week 39', 'Week 40'],
		data: [285000, 312000, 298000, 325000, 341000, 286000]
	};

	const monthlyData = {
		labels: ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'],
		data: [1250000, 1180000, 1420000, 1380000, 1560000, 1847000]
	};

	const trendChart = new Chart(ctx, {
		type: 'line',
		data: {
			labels: dailyData.labels,
			datasets: [{
				label: 'Sales',
				data: dailyData.data,
				borderColor: '#bfa14a',
				backgroundColor: 'rgba(191, 161, 74, 0.1)',
				borderWidth: 3,
				fill: true,
				tension: 0.4,
				pointRadius: 5,
				pointBackgroundColor: '#bfa14a',
				pointBorderColor: '#fff',
				pointBorderWidth: 2,
				pointHoverRadius: 7
			}]
		},
		options: {
			responsive: true,
			maintainAspectRatio: false,
			plugins: {
				legend: {
					display: false
				},
				tooltip: {
					callbacks: {
						label: function(context) {
							return `Sales: ₱${context.parsed.y.toLocaleString()}`;
						}
					}
				}
			},
			scales: {
				y: {
					beginAtZero: true,
					ticks: {
						callback: function(value) {
							return '₱' + (value / 1000) + 'K';
						},
						font: {
							family: 'Montserrat',
							size: 11
						}
					},
					grid: {
						color: '#f0f0f0'
					}
				},
				x: {
					ticks: {
						font: {
							family: 'Montserrat',
							size: 11
						}
					},
					grid: {
						display: false
					}
				}
			}
		}
	});

	// Period selector buttons
	const periodButtons = document.querySelectorAll('.period-btn');
	periodButtons.forEach(btn => {
		btn.addEventListener('click', function() {
			periodButtons.forEach(b => b.classList.remove('active'));
			this.classList.add('active');
			
			const period = this.dataset.period;
			let newData;
			
			if (period === 'daily') {
				newData = dailyData;
			} else if (period === 'weekly') {
				newData = weeklyData;
			} else {
				newData = monthlyData;
			}
			
			trendChart.data.labels = newData.labels;
			trendChart.data.datasets[0].data = newData.data;
			trendChart.update();
		});
	});
}

// Initialize Filters
function initializeFilters() {
	const categoryFilter = document.getElementById('categoryFilter');
	const sellerFilter = document.getElementById('sellerFilter');
	const startDate = document.getElementById('startDate');
	const endDate = document.getElementById('endDate');

	if (categoryFilter) {
		categoryFilter.addEventListener('change', applyFilters);
	}
	if (sellerFilter) {
		sellerFilter.addEventListener('change', applyFilters);
	}
	if (startDate) {
		startDate.addEventListener('change', applyFilters);
	}
	if (endDate) {
		endDate.addEventListener('change', applyFilters);
	}
}

function applyFilters() {
	const category = document.getElementById('categoryFilter')?.value || '';
	const seller = document.getElementById('sellerFilter')?.value || '';
	const startDate = document.getElementById('startDate')?.value || '';
	const endDate = document.getElementById('endDate')?.value || '';

	console.log('Applying filters:', { category, seller, startDate, endDate });
	// In a real application, this would filter the table data
	// For now, it's just a placeholder
}

// Initialize Export Buttons
function initializeExportButtons() {
	const exportExcel = document.getElementById('exportExcel');
	const exportPDF = document.getElementById('exportPDF');

	if (exportExcel) {
		exportExcel.addEventListener('click', function() {
			exportReport('excel');
		});
	}

	if (exportPDF) {
		exportPDF.addEventListener('click', function() {
			exportReport('pdf');
		});
	}
}

// Export Report Function
function exportReport(format) {
	// Get filter values
	const startDate = document.getElementById('startDate')?.value || '';
	const endDate = document.getElementById('endDate')?.value || '';
	const category = document.getElementById('categoryFilter')?.value || '';
	
	// Build query parameters
	const params = new URLSearchParams();
	if (startDate) params.append('start_date', startDate);
	if (endDate) params.append('end_date', endDate);
	if (category) params.append('category', category);
	
	// Build URL
	let baseUrl;
	if (format === 'excel') {
		baseUrl = '/admin/sales-reports/export-excel';
	} else {
		baseUrl = '/admin/sales-reports/export-pdf';
	}
	const url = `${baseUrl}?${params.toString()}`;
	
	// Show loading indicator
	let button;
	if (format === 'excel') {
		button = document.getElementById('exportExcel');
	} else {
		button = document.getElementById('exportPDF');
	}
	const originalText = button.innerHTML;
	button.innerHTML = '<i class="bi bi-hourglass-split"></i> Exporting...';
	button.disabled = true;
	
	// Download file
	fetch(url)
		.then(response => {
			if (!response.ok) {
				throw new Error('Export failed');
			}
			return response.blob();
		})
		.then(blob => {
			// Create download link
			const downloadUrl = window.URL.createObjectURL(blob);
			const a = document.createElement('a');
			a.href = downloadUrl;
			const extension = format === 'excel' ? 'xlsx' : format;
			a.download = `sales_report_${new Date().toISOString().split('T')[0]}.${extension}`;
			document.body.appendChild(a);
			a.click();
			window.URL.revokeObjectURL(downloadUrl);
			document.body.removeChild(a);
			
			// Reset button
			button.innerHTML = originalText;
			button.disabled = false;
			
			// Show success message
			const formatName = format === 'excel' ? 'Excel' : format.toUpperCase();
			showNotification(`${formatName} exported successfully!`, 'success');
		})
		.catch(error => {
			console.error('Export error:', error);
			button.innerHTML = originalText;
			button.disabled = false;
			showNotification(`Failed to export ${format.toUpperCase()}. Please try again.`, 'error');
		});
}

// Show notification helper
function showNotification(message, type) {
	// Create notification element
	const notification = document.createElement('div');
	notification.style.cssText = `
		position: fixed;
		top: 20px;
		right: 20px;
		padding: 15px 25px;
		background: ${type === 'success' ? '#2ecc71' : '#e74c3c'};
		color: white;
		border-radius: 5px;
		box-shadow: 0 4px 6px rgba(0,0,0,0.1);
		z-index: 10000;
		font-family: Montserrat, sans-serif;
		font-size: 14px;
		animation: slideIn 0.3s ease-out;
	`;
	notification.textContent = message;
	
	// Add animation
	const style = document.createElement('style');
	style.textContent = `
		@keyframes slideIn {
			from { transform: translateX(400px); opacity: 0; }
			to { transform: translateX(0); opacity: 1; }
		}
	`;
	document.head.appendChild(style);
	
	document.body.appendChild(notification);
	
	// Remove after 3 seconds
	setTimeout(() => {
		notification.style.animation = 'slideIn 0.3s ease-out reverse';
		setTimeout(() => {
			document.body.removeChild(notification);
			document.head.removeChild(style);
		}, 300);
	}, 3000);
}

// Initialize Search
function initializeSearch() {
	const searchInput = document.getElementById('orderSearch');
	if (!searchInput) return;

	searchInput.addEventListener('input', function() {
		const searchTerm = this.value.toLowerCase();
		const tableRows = document.querySelectorAll('.payments-table tbody tr');

		tableRows.forEach(row => {
			const text = row.textContent.toLowerCase();
			if (text.includes(searchTerm)) {
				row.style.display = '';
			} else {
				row.style.display = 'none';
			}
		});
	});
}

// Initialize View Details Buttons
function initializeViewDetailsButtons() {
	const viewButtons = document.querySelectorAll('.view-btn');
	const modal = document.getElementById('orderDetailsModal');
	const overlay = document.getElementById('orderDetailsOverlay');
	const closeBtn = document.getElementById('closeOrderDetails');
	const closeFooterBtn = document.getElementById('closeOrderDetailsBtn');

	viewButtons.forEach(button => {
		button.addEventListener('click', function() {
			// Get data from button attributes
			const orderNumber = this.dataset.orderNumber;
			const date = this.dataset.date;
			const seller = this.dataset.seller;
			const buyer = this.dataset.buyer;
			const amount = parseFloat(this.dataset.amount);
			const commission = parseFloat(this.dataset.commission);
			const items = this.dataset.items;
			const categories = this.dataset.categories;

			// Calculate net amount
			const netAmount = amount - commission;

			// Update modal content
			document.getElementById('orderNumber').textContent = '#' + orderNumber;
			document.getElementById('orderDate').textContent = date;
			document.getElementById('orderSeller').textContent = seller;
			document.getElementById('orderBuyer').textContent = buyer;
			document.getElementById('orderItems').textContent = items;
			document.getElementById('orderCategories').textContent = categories;
			document.getElementById('orderAmount').textContent = '₱' + amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
			document.getElementById('orderCommission').textContent = '₱' + commission.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
			document.getElementById('orderNetAmount').textContent = '₱' + netAmount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

			// Update avatar with first letter of order number
			const avatarLetter = orderNumber.charAt(0);
			document.getElementById('orderAvatar').textContent = avatarLetter;

			// Show modal
			modal.classList.add('active');
			overlay.classList.add('active');
		});
	});

	// Close modal handlers
	function closeModal() {
		modal.classList.remove('active');
		overlay.classList.remove('active');
	}

	if (closeBtn) {
		closeBtn.addEventListener('click', closeModal);
	}

	if (closeFooterBtn) {
		closeFooterBtn.addEventListener('click', closeModal);
	}

	if (overlay) {
		overlay.addEventListener('click', closeModal);
	}

	// Close on ESC key
	document.addEventListener('keydown', function(e) {
		if (e.key === 'Escape' && modal.classList.contains('active')) {
			closeModal();
		}
	});
}
