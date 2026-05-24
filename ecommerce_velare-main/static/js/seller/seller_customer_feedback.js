// @ts-nocheck
// Seller Customer Feedback Page JavaScript

// Global variables
let feedbackData = [];
let statisticsData = {};
let productQualityData = {};
let feedbackDistributionChart = null;
let ratingTrendChart = null;

// Pagination variables
let currentPage = 1;
const itemsPerPage = 10;
let filteredData = [];

// Initialize page
document.addEventListener('DOMContentLoaded', function() {
	fetchReviewsData();
	setupEventListeners();
	fetchChartData();
});

// Fetch reviews data from API
async function fetchReviewsData() {
	try {
		const dateFrom = document.getElementById('dateFrom').value;
		const dateTo = document.getElementById('dateTo').value;
		
		let queryParams = '';
		if (dateFrom && dateTo) {
			queryParams = `?dateFrom=${dateFrom}&dateTo=${dateTo}`;
		}
		
		console.log('🔍 Fetching reviews with params:', queryParams);
		
		const response = await fetch(`/api/seller/reviews${queryParams}`);
		const data = await response.json();
		
		if (data.success) {
			feedbackData = data.reviews;
			statisticsData = data.statistics;
			productQualityData = data.product_quality;
			filteredData = [...feedbackData];
			
			console.log('✅ Loaded reviews:', feedbackData.length);
			
			// Update UI
			updateSummaryCards();
			updateProductQuality();
			updateFeedbackDisplay();
		} else {
			console.error('Failed to fetch reviews:', data.message);
			showEmptyState();
		}
	} catch (error) {
		console.error('Error fetching reviews:', error);
		showEmptyState();
	}
}

// Show empty state
function showEmptyState() {
	document.getElementById('averageRatingNumber').textContent = '0.0';
	document.getElementById('totalFeedback').textContent = '0';
	document.getElementById('positiveReviews').textContent = '0%';
	document.getElementById('feedbackTableBody').innerHTML = '<tr><td colspan="5" style="text-align:center;padding:40px;">No reviews yet</td></tr>';
}

// Update summary cards
function updateSummaryCards() {
	if (!statisticsData) return;
	
	document.getElementById('averageRatingNumber').textContent = statisticsData.avg_rating || '0.0';
	document.getElementById('totalFeedback').textContent = statisticsData.total_reviews || '0';
	document.getElementById('positiveReviews').textContent = statisticsData.positive_percentage + '%' || '0%';
	
	// Update star display
	const starDisplay = document.getElementById('averageRatingStars');
	starDisplay.innerHTML = generateStars(statisticsData.avg_rating || 0);
}

// Update product quality sections
function updateProductQuality() {
	if (!productQualityData) return;
	
	// Top rated products
	const topRatedContainer = document.getElementById('topRatedProducts');
	topRatedContainer.innerHTML = '';
	
	if (productQualityData.top_rated && productQualityData.top_rated.length > 0) {
		productQualityData.top_rated.forEach(product => {
			const item = document.createElement('div');
			item.className = 'quality-product-item';
			item.innerHTML = `
				<div class="quality-product-name">${product.product_name}</div>
				<div class="quality-product-rating">
					<div class="star-display-small">
						${generateStars(parseFloat(product.avg_rating))}
					</div>
					<span class="quality-rating-number">${parseFloat(product.avg_rating).toFixed(1)}</span>
				</div>
				<div class="quality-product-count">${product.review_count} review${product.review_count > 1 ? 's' : ''}</div>
			`;
			topRatedContainer.appendChild(item);
		});
	} else {
		topRatedContainer.innerHTML = '<p style="text-align:center;color:#999;padding:20px;">No top rated products yet</p>';
	}
	
	// Lowest rated products
	const lowestRatedContainer = document.getElementById('lowestRatedProducts');
	lowestRatedContainer.innerHTML = '';
	
	if (productQualityData.lowest_rated && productQualityData.lowest_rated.length > 0) {
		productQualityData.lowest_rated.forEach(product => {
			const item = document.createElement('div');
			item.className = 'quality-product-item';
			item.innerHTML = `
				<div class="quality-product-name">${product.product_name}</div>
				<div class="quality-product-rating">
					<div class="star-display-small">
						${generateStars(parseFloat(product.avg_rating))}
					</div>
					<span class="quality-rating-number">${parseFloat(product.avg_rating).toFixed(1)}</span>
				</div>
				<div class="quality-product-count">${product.review_count} review${product.review_count > 1 ? 's' : ''}</div>
			`;
			lowestRatedContainer.appendChild(item);
		});
	} else {
		lowestRatedContainer.innerHTML = '<p style="text-align:center;color:#999;padding:20px;">All products are well rated!</p>';
	}
}

// Update rating breakdown bars
function updateRatingBreakdown(ratingCounts) {
	if (!ratingCounts) return;
	
	const total = Object.values(ratingCounts).reduce((sum, count) => sum + count, 0);
	if (total === 0) return;
	
	for (let rating = 5; rating >= 1; rating--) {
		const count = ratingCounts[rating] || 0;
		const percentage = (count / total) * 100;
		
		const barFill = document.querySelector(`.rating-bar-fill[data-rating="${rating}"]`);
		const barCount = barFill.parentElement.nextElementSibling;
		
		if (barFill) barFill.style.width = percentage + '%';
		if (barCount) barCount.textContent = count;
	}
}

// Setup event listeners
function setupEventListeners() {
	// Filter listeners
	document.getElementById('dateFrom').addEventListener('change', function() {
		const dateTo = document.getElementById('dateTo').value;
		if (dateTo) {
			// Both dates selected - fetch from API
			fetchReviewsData();
			fetchChartData();
		}
	});
	document.getElementById('dateTo').addEventListener('change', function() {
		const dateFrom = document.getElementById('dateFrom').value;
		if (dateFrom) {
			// Both dates selected - fetch from API
			fetchReviewsData();
			fetchChartData();
		}
	});
	document.getElementById('ratingFilter').addEventListener('change', applyFilters);
	document.getElementById('searchFeedback').addEventListener('input', applyFilters);
	
	// Pagination listeners
	document.getElementById('prevPageBtn').addEventListener('click', () => changePage(-1));
	document.getElementById('nextPageBtn').addEventListener('click', () => changePage(1));
	
	// Export button
	document.getElementById('exportFeedbackBtn').addEventListener('click', exportToCSV);
}

// Calculate average rating per product
function calculateProductAverages() {
	const productRatings = {};
	
	feedbackData.forEach(feedback => {
		if (!productRatings[feedback.product_name]) {
			productRatings[feedback.product_name] = {
				total: 0,
				count: 0,
				average: 0
			};
		}
		productRatings[feedback.product_name].total += feedback.rating;
		productRatings[feedback.product_name].count++;
	});
	
	// Calculate averages
	for (const product in productRatings) {
		productRatings[product].average = 
			productRatings[product].total / productRatings[product].count;
	}
	
	return productRatings;
}

// Apply filters
function applyFilters() {
	const ratingFilter = document.getElementById('ratingFilter').value;
	const searchTerm = document.getElementById('searchFeedback').value.toLowerCase();
	
	console.log('🔍 Applying local filters - rating:', ratingFilter, 'search:', searchTerm);
	
	filteredData = feedbackData.filter(feedback => {
		// Rating filter
		let ratingMatch = true;
		if (ratingFilter !== 'all') {
			const filterRating = parseInt(ratingFilter);
			ratingMatch = Math.floor(feedback.rating) === filterRating;
		}
		
		// Search filter
		let searchMatch = true;
		if (searchTerm) {
			searchMatch = feedback.review_text?.toLowerCase().includes(searchTerm) ||
						  feedback.buyer_name?.toLowerCase().includes(searchTerm) ||
						  feedback.product_name?.toLowerCase().includes(searchTerm);
		}
		
		return ratingMatch && searchMatch;
	});
	
	console.log('✅ Filtered results:', filteredData.length, 'of', feedbackData.length);
	
	currentPage = 1;
	updateFeedbackDisplay();
	calculateSummaryStats();
}

// Update feedback display
function updateFeedbackDisplay() {
	const tbody = document.getElementById('feedbackTableBody');
	const startIndex = (currentPage - 1) * itemsPerPage;
	const endIndex = startIndex + itemsPerPage;
	const pageData = filteredData.slice(startIndex, endIndex);
	
	// Clear existing rows
	tbody.innerHTML = '';
	
	if (pageData.length === 0) {
		tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;padding:40px;">No reviews found</td></tr>';
		return;
	}
	
	// Add rows
	pageData.forEach(feedback => {
		const row = document.createElement('tr');
		row.className = 'table-row';
		
		row.innerHTML = `
			<td class="table-cell rating-cell">
				<div class="star-rating">
					${generateStars(feedback.rating)}
				</div>
			</td>
			<td class="table-cell comment-cell">${feedback.review_text || 'No comment'}</td>
			<td class="table-cell">${feedback.buyer_name}</td>
			<td class="table-cell">${feedback.product_name}</td>
			<td class="table-cell">${formatDate(feedback.created_at)}</td>
		`;
		
		tbody.appendChild(row);
	});
	
	// Update pagination
	updatePagination();
}

// Generate star HTML
function generateStars(rating) {
	let starsHTML = '';
	const fullStars = Math.floor(rating);
	const hasHalfStar = rating % 1 !== 0;
	
	for (let i = 0; i < fullStars; i++) {
		starsHTML += '<i class="bi bi-star-fill"></i>';
	}
	
	if (hasHalfStar) {
		starsHTML += '<i class="bi bi-star-half"></i>';
	}
	
	const emptyStars = 5 - Math.ceil(rating);
	for (let i = 0; i < emptyStars; i++) {
		starsHTML += '<i class="bi bi-star"></i>';
	}
	
	return starsHTML;
}

// Format date
function formatDate(dateString) {
	const date = new Date(dateString);
	const options = { year: 'numeric', month: 'short', day: 'numeric' };
	return date.toLocaleDateString('en-US', options);
}

// Update pagination
function updatePagination() {
	const totalPages = Math.ceil(filteredData.length / itemsPerPage);
	
	document.getElementById('currentPage').textContent = currentPage;
	document.getElementById('totalPages').textContent = totalPages;
	document.getElementById('displayedCount').textContent = Math.min(filteredData.length, currentPage * itemsPerPage);
	document.getElementById('totalCount').textContent = filteredData.length;
	
	// Update button states
	document.getElementById('prevPageBtn').disabled = currentPage === 1;
	document.getElementById('nextPageBtn').disabled = currentPage >= totalPages;
}

// Change page
function changePage(direction) {
	currentPage += direction;
	updateFeedbackDisplay();
}

// Calculate summary statistics for filtered data
function calculateSummaryStats() {
	if (filteredData.length === 0) {
		document.getElementById('displayedCount').textContent = '0';
		document.getElementById('totalCount').textContent = statisticsData.total_reviews || '0';
		return;
	}
	
	// Update displayed count
	document.getElementById('displayedCount').textContent = Math.min(filteredData.length, currentPage * itemsPerPage);
	document.getElementById('totalCount').textContent = filteredData.length;
}

// Export to CSV
function exportToCSV() {
	const headers = ['Rating', 'Comment', 'Customer', 'Product', 'Date'];
	const rows = filteredData.map(item => [
		item.rating,
		`"${item.review_text || ''}"`,
		item.buyer_name,
		item.product_name,
		formatDate(item.created_at)
	]);
	
	let csvContent = headers.join(',') + '\n';
	rows.forEach(row => {
		csvContent += row.join(',') + '\n';
	});
	
	// Create download link
	const blob = new Blob([csvContent], { type: 'text/csv' });
	const url = window.URL.createObjectURL(blob);
	const a = document.createElement('a');
	a.href = url;
	a.download = `customer_feedback_${new Date().toISOString().split('T')[0]}.csv`;
	document.body.appendChild(a);
	a.click();
	document.body.removeChild(a);
	window.URL.revokeObjectURL(url);
}

// Fetch chart data from API
async function fetchChartData() {
	try {
		const dateFrom = document.getElementById('dateFrom').value;
		const dateTo = document.getElementById('dateTo').value;
		
		let queryParams = '';
		if (dateFrom && dateTo) {
			queryParams = `?dateFrom=${dateFrom}&dateTo=${dateTo}`;
		}
		
		const response = await fetch(`/api/seller/reviews/charts${queryParams}`);
		const chartData = await response.json();
		
		if (chartData) {
			updateChartTitles(dateFrom, dateTo, chartData.trend);
			updateRatingBreakdown(chartData.rating_counts);
			initializeFeedbackDistributionChart(chartData.distribution);
			initializeRatingTrendChart(chartData.trend);
		}
	} catch (error) {
		console.error('Error fetching chart data:', error);
	}
}

// Update chart titles with date range
function updateChartTitles(dateFrom, dateTo, trendData) {
	if (dateFrom && dateTo) {
		const fromDate = new Date(dateFrom);
		const toDate = new Date(dateTo);
		
		const formatDate = (date) => {
			return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
		};
		
		const dateRangeText = `${formatDate(fromDate)} - ${formatDate(toDate)}`;
		
		const distributionInfo = document.getElementById('distributionChartInfo');
		const trendInfo = document.getElementById('trendChartInfo');
		const trendLabel = document.getElementById('trendChartLabel');
		const breakdownRange = document.getElementById('breakdownDateRange');
		
		if (distributionInfo) {
			distributionInfo.textContent = dateRangeText;
		}
		
		if (trendInfo) {
			trendInfo.textContent = dateRangeText;
		}
		
		if (trendLabel && trendData && trendData.label) {
			trendLabel.textContent = trendData.label;
		}
		
		if (breakdownRange) {
			breakdownRange.textContent = `(${dateRangeText})`;
		}
	}
}

// Feedback Distribution Chart (Bar Chart)
function initializeFeedbackDistributionChart(distributionData) {
	const ctx = document.getElementById('feedbackDistributionChart');
	if (!ctx) return;
	
	// Destroy existing chart if it exists
	if (feedbackDistributionChart) {
		feedbackDistributionChart.destroy();
	}
	
	feedbackDistributionChart = new Chart(ctx, {
		type: 'bar',
		data: {
			labels: distributionData?.labels || ['1 Star', '2 Stars', '3 Stars', '4 Stars', '5 Stars'],
			datasets: [{
				label: 'Number of Reviews',
				data: distributionData?.data || [0, 0, 0, 0, 0],
				backgroundColor: [
					'rgba(232, 220, 200, 0.8)',
					'rgba(224, 201, 166, 0.8)',
					'rgba(211, 189, 155, 0.8)',
					'rgba(191, 161, 74, 0.8)',
					'rgba(212, 175, 55, 0.8)'
				],
				borderColor: [
					'rgba(232, 220, 200, 1)',
					'rgba(224, 201, 166, 1)',
					'rgba(211, 189, 155, 1)',
					'rgba(191, 161, 74, 1)',
					'rgba(212, 175, 55, 1)'
				],
				borderWidth: 1.5
			}]
		},
		options: {
			responsive: true,
			maintainAspectRatio: false,
			plugins: {
				legend: {
					display: false
				},
				title: {
					display: false
				}
			},
			scales: {
				y: {
					beginAtZero: true,
					ticks: {
						stepSize: 10,
						font: {
							family: "'Montserrat', sans-serif",
							size: 11
						},
						color: '#6d6552'
					},
					grid: {
						color: 'rgba(224, 215, 198, 0.3)'
					}
				},
				x: {
					ticks: {
						font: {
							family: "'Montserrat', sans-serif",
							size: 11
						},
						color: '#6d6552'
					},
					grid: {
						display: false
					}
				}
			}
		}
	});
}

// Rating Trend Chart (Line Chart)
function initializeRatingTrendChart(trendData) {
	const ctx = document.getElementById('ratingTrendChart');
	if (!ctx) return;
	
	// Destroy existing chart if it exists
	if (ratingTrendChart) {
		ratingTrendChart.destroy();
	}
	
	ratingTrendChart = new Chart(ctx, {
		type: 'line',
		data: {
			labels: trendData?.labels || ['No Data'],
			datasets: [{
				label: trendData?.label || 'Average Rating',
				data: trendData?.data || [0],
				borderColor: 'rgba(212, 175, 55, 1)',
				backgroundColor: 'rgba(212, 175, 55, 0.1)',
				borderWidth: 2.5,
				fill: true,
				tension: 0.4,
				pointBackgroundColor: 'rgba(212, 175, 55, 1)',
				pointBorderColor: '#fff',
				pointBorderWidth: 2,
				pointRadius: 5,
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
				title: {
					display: false
				}
			},
			scales: {
				y: {
					beginAtZero: false,
					min: 0,
					max: 5,
					ticks: {
						stepSize: 1,
						font: {
							family: "'Montserrat', sans-serif",
							size: 11
						},
						color: '#6d6552'
					},
					grid: {
						color: 'rgba(224, 215, 198, 0.3)'
					}
				},
				x: {
					ticks: {
						font: {
							family: "'Montserrat', sans-serif",
							size: 11
						},
						color: '#6d6552'
					},
					grid: {
						display: false
					}
				}
			}
		}
	});
}
