-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Nov 29, 2025 at 11:28 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `velare_ecommerce`
--

-- --------------------------------------------------------

--
-- Table structure for table `addresses`
--

CREATE TABLE `addresses` (
  `address_id` int(11) NOT NULL,
  `user_type` enum('buyer','seller','rider') NOT NULL,
  `user_ref_id` int(11) NOT NULL,
  `recipient_name` varchar(200) DEFAULT NULL,
  `phone_number` varchar(20) DEFAULT NULL,
  `full_address` text NOT NULL,
  `region` varchar(100) DEFAULT NULL,
  `province` varchar(100) DEFAULT NULL,
  `city` varchar(100) DEFAULT NULL,
  `barangay` varchar(100) DEFAULT NULL,
  `street_name` varchar(200) DEFAULT NULL,
  `house_number` varchar(50) DEFAULT NULL,
  `postal_code` varchar(20) DEFAULT NULL,
  `is_default` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `addresses`
--

INSERT INTO `addresses` (`address_id`, `user_type`, `user_ref_id`, `recipient_name`, `phone_number`, `full_address`, `region`, `province`, `city`, `barangay`, `street_name`, `house_number`, `postal_code`, `is_default`, `created_at`) VALUES
(14, 'seller', 7, 'Justine Mark Gahi', '09124312313', '12, asdasdasdad, New Cebu, Lambayong, Sultan Kudarat, SOCCSKSARGEN, 4235', 'SOCCSKSARGEN', 'Sultan Kudarat', 'Lambayong', 'New Cebu', 'asdasdasdad', '12', '4235', 1, '2025-10-29 10:04:39'),
(15, 'buyer', 8, 'jeje mon', '09234253465', '12, fsdasdasd, Bangkas Heights, City of Davao, Davao Del Sur, Davao Region', 'Davao Region', 'Davao Del Sur', 'City of Davao', 'Bangkas Heights', 'fsdasdasd', '12', '8016', 1, '2025-10-29 12:21:33'),
(16, 'rider', 4, 're re', '09413142325', '23, asdasdasda, Bayanan, City of Muntinlupa, NCR', 'NCR', '', 'City of Muntinlupa', 'Bayanan', 'asdasdasda', '23', '1772', 1, '2025-10-29 12:30:52'),
(17, 'buyer', 9, 'hey low', '09234234234', 'fsdfsdfsf, fsdfsdfsd, Pamplona Dos, City of Las Piñas, NCR', 'NCR', '', 'City of Las Piñas', 'Pamplona Dos', 'fsdfsdfsd', 'fsdfsdfsf', '1750', 1, '2025-11-17 01:34:23'),
(18, 'rider', 5, 'Mark Justine Gahi', '09525534534', 'fsfdsdfsdfd, fsdfsdsdfsfsd, San Miguel, Cateel, Davao Oriental, Davao Region', 'Davao Region', 'Davao Oriental', 'Cateel', 'San Miguel', 'fsdfsdsdfsfsd', 'fsfdsdfsdfd', '8205', 1, '2025-11-17 09:32:07'),
(19, 'seller', 8, 'mark gahi', '09456456456', 'fsdfsdfsdfsdf, fdsdfsdfsd, Maybula, Tulunan, Cotabato, SOCCSKSARGEN, 9403', 'SOCCSKSARGEN', 'Cotabato', 'Tulunan', 'Maybula', 'fdsdfsdfsd', 'fsdfsdfsdfsdf', '9403', 1, '2025-11-17 09:46:45'),
(20, 'buyer', 10, 'Jake Jaqueca', '09534534534', '45345345345, 5345353, Lourmah, Mahayag, Zamboanga Del Sur, Zamboanga Peninsula', 'Zamboanga Peninsula', 'Zamboanga Del Sur', 'Mahayag', 'Lourmah', '5345353', '45345345345', '7026', 1, '2025-11-19 05:22:54'),
(21, 'rider', 6, 'Symon Beato', '09423423434', 'dfsdfsdf, fsdfsdfs, Lower Salug Daku, Mahayag, Zamboanga Del Sur, Zamboanga Peninsula', 'Zamboanga Peninsula', 'Zamboanga Del Sur', 'Mahayag', 'Lower Salug Daku', 'fsdfsdfs', 'dfsdfsdf', '7026', 1, '2025-11-19 05:29:06'),
(24, 'buyer', 8, 'dfhstrfh', '09968957687', 'CALABARZON, Laguna, Santa Cruz, Labuin', 'CALABARZON', 'Laguna', 'Santa Cruz', 'Labuin', 'yakala', '69', '4009', 0, '2025-11-23 00:28:47'),
(26, 'buyer', 10, 'Full name', '09342342342', '15, Jacinto, CALABARZON, Laguna, Cavinti, Poblacion', 'CALABARZON', 'Laguna', 'Cavinti', 'Poblacion', 'Jacinto', '15', '4013', 0, '2025-11-23 01:49:58');

-- --------------------------------------------------------

--
-- Table structure for table `admins`
--

CREATE TABLE `admins` (
  `admin_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `first_name` varchar(100) NOT NULL,
  `last_name` varchar(100) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `admins`
--

INSERT INTO `admins` (`admin_id`, `user_id`, `first_name`, `last_name`, `created_at`) VALUES
(1, 1, 'Admin', 'Velare', '2025-10-21 10:31:47');

-- --------------------------------------------------------

--
-- Table structure for table `buyers`
--

CREATE TABLE `buyers` (
  `buyer_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `first_name` varchar(100) NOT NULL,
  `last_name` varchar(100) NOT NULL,
  `gender` enum('Male','Female','Other') DEFAULT NULL,
  `phone_number` varchar(20) DEFAULT NULL,
  `id_type` varchar(50) DEFAULT NULL,
  `id_file_path` varchar(255) DEFAULT NULL,
  `profile_image` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `account_status` varchar(20) DEFAULT 'active',
  `suspension_end` datetime DEFAULT NULL,
  `suspension_reason` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `buyers`
--

INSERT INTO `buyers` (`buyer_id`, `user_id`, `first_name`, `last_name`, `gender`, `phone_number`, `id_type`, `id_file_path`, `profile_image`, `created_at`, `account_status`, `suspension_end`, `suspension_reason`) VALUES
(8, 20, 'jeje', 'mon', NULL, NULL, 'sss', '/static/uploads/buyer_ids/user_8/id_buyer_jejemon_gmail.com_Screenshot_2025-10-24_114625.png', '/static/uploads/profiles/buyer_20_Mesa-de-trabajo-1-copia-22x.png', '2025-10-29 12:21:33', 'active', NULL, NULL),
(9, 22, 'hey', 'low', NULL, NULL, 'driver_license', '/static/uploads/buyer_ids/user_9/id_buyer_heylow_gmail.com_barong_1.jpg', NULL, '2025-11-17 01:34:23', 'active', NULL, NULL),
(10, 25, 'Jake', 'Jaqueca', NULL, NULL, 'national_id', '/static/uploads/buyer_ids/user_10/id_buyer_jakemagbuhosjaqueca_gmail.com_stampita_2.JPG', NULL, '2025-11-19 05:22:54', 'active', NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `buyer_vouchers`
--

CREATE TABLE `buyer_vouchers` (
  `buyer_voucher_id` int(11) NOT NULL,
  `buyer_id` int(11) NOT NULL,
  `voucher_id` int(11) NOT NULL,
  `is_used` tinyint(1) DEFAULT 0,
  `times_remaining` int(11) DEFAULT 1,
  `used_at` timestamp NULL DEFAULT NULL,
  `claimed_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `buyer_vouchers`
--

INSERT INTO `buyer_vouchers` (`buyer_voucher_id`, `buyer_id`, `voucher_id`, `is_used`, `times_remaining`, `used_at`, `claimed_at`) VALUES
(6, 8, 10, 1, 2, '2025-11-22 20:55:40', '2025-11-22 20:30:52'),
(7, 10, 10, 0, 0, NULL, '2025-11-22 20:30:52'),
(8, 8, 4, 1, 2, '2025-11-23 01:17:34', '2025-11-22 20:30:52'),
(9, 10, 4, 1, 0, '2025-11-23 01:25:51', '2025-11-22 20:30:52'),
(10, 10, 10, 0, 1, NULL, '2025-11-28 00:57:54'),
(11, 10, 10, 0, 1, NULL, '2025-11-28 00:57:56'),
(12, 10, 10, 0, 1, NULL, '2025-11-29 09:55:03');

-- --------------------------------------------------------

--
-- Table structure for table `cart`
--

CREATE TABLE `cart` (
  `cart_id` int(11) NOT NULL,
  `buyer_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `variant_id` int(11) DEFAULT NULL,
  `quantity` int(11) NOT NULL DEFAULT 1,
  `added_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `cart`
--

INSERT INTO `cart` (`cart_id`, `buyer_id`, `product_id`, `variant_id`, `quantity`, `added_at`) VALUES
(27, 10, 42, 112, 1, '2025-11-23 01:48:01'),
(28, 10, 42, 110, 99, '2025-11-23 01:52:26'),
(30, 10, 42, 114, 1, '2025-11-23 02:03:14'),
(31, 8, 42, 114, 1, '2025-11-26 05:25:58'),
(32, 8, 41, 109, 1, '2025-11-26 05:27:03');

-- --------------------------------------------------------

--
-- Table structure for table `conversations`
--

CREATE TABLE `conversations` (
  `conversation_id` int(11) NOT NULL,
  `buyer_id` int(11) NOT NULL,
  `seller_id` int(11) DEFAULT NULL,
  `rider_id` int(11) DEFAULT NULL,
  `delivery_id` int(11) DEFAULT NULL,
  `last_message` text DEFAULT NULL,
  `buyer_unread_count` int(11) DEFAULT 0,
  `seller_unread_count` int(11) DEFAULT 0,
  `rider_unread_count` int(11) DEFAULT 0,
  `last_message_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `conversations`
--

INSERT INTO `conversations` (`conversation_id`, `buyer_id`, `seller_id`, `rider_id`, `delivery_id`, `last_message`, `buyer_unread_count`, `seller_unread_count`, `rider_unread_count`, `last_message_at`, `created_at`) VALUES
(2, 8, 7, NULL, NULL, 'beybe', 0, 0, 0, '2025-11-26 04:57:30', '2025-11-14 05:38:39'),
(3, 8, NULL, 4, 3, 'heys', 0, 1, 0, '2025-11-19 05:12:20', '2025-11-19 05:12:04');

-- --------------------------------------------------------

--
-- Table structure for table `deliveries`
--

CREATE TABLE `deliveries` (
  `delivery_id` int(11) NOT NULL,
  `order_id` int(11) NOT NULL,
  `rider_id` int(11) DEFAULT NULL,
  `pickup_address` text NOT NULL,
  `delivery_address` text NOT NULL,
  `delivery_fee` decimal(10,2) NOT NULL,
  `rider_earnings` decimal(10,2) DEFAULT 0.00,
  `paid_by_platform` tinyint(1) DEFAULT 0,
  `status` enum('preparing','pending','assigned','in_transit','delivered','cancelled') DEFAULT NULL,
  `assigned_at` timestamp NULL DEFAULT NULL,
  `picked_up_at` timestamp NULL DEFAULT NULL,
  `delivered_at` timestamp NULL DEFAULT NULL,
  `completed_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `deliveries`
--

INSERT INTO `deliveries` (`delivery_id`, `order_id`, `rider_id`, `pickup_address`, `delivery_address`, `delivery_fee`, `rider_earnings`, `paid_by_platform`, `status`, `assigned_at`, `picked_up_at`, `delivered_at`, `completed_at`, `created_at`) VALUES
(1, 1, 4, '12, asdasdasdad, New Cebu, Lambayong, Sultan Kudarat, SOCCSKSARGEN, 4235', '12, fsdasdasd, Bangkas Heights, City of Davao, Davao Del Sur, Davao Region', 0.00, 49.00, 1, 'delivered', '2025-11-21 06:34:00', '2025-11-21 06:34:24', '2025-11-21 06:41:08', '2025-11-21 06:52:59', '2025-11-21 06:01:35'),
(2, 2, 4, '12, asdasdasdad, New Cebu, Lambayong, Sultan Kudarat, SOCCSKSARGEN, 4235', '45345345345, 5345353, Lourmah, Mahayag, Zamboanga Del Sur, Zamboanga Peninsula', 49.00, 49.00, 0, 'delivered', '2025-11-21 08:50:33', '2025-11-21 08:50:45', '2025-11-21 08:59:04', NULL, '2025-11-21 08:42:56'),
(3, 3, 4, '12, asdasdasdad, New Cebu, Lambayong, Sultan Kudarat, SOCCSKSARGEN, 4235', '12, fsdasdasd, Bangkas Heights, City of Davao, Davao Del Sur, Davao Region', 49.00, 49.00, 1, 'delivered', '2025-11-22 02:52:42', '2025-11-22 02:54:20', '2025-11-22 02:56:00', NULL, '2025-11-22 01:53:19'),
(4, 5, 4, '12, asdasdasdad, New Cebu, Lambayong, Sultan Kudarat, SOCCSKSARGEN, 4235', '12, fsdasdasd, Bangkas Heights, City of Davao, Davao Del Sur, Davao Region', 49.00, 49.00, 0, 'delivered', '2025-11-22 21:07:20', '2025-11-22 21:15:23', '2025-11-22 21:31:26', NULL, '2025-11-22 20:38:00'),
(5, 6, 4, '12, asdasdasdad, New Cebu, Lambayong, Sultan Kudarat, SOCCSKSARGEN, 4235', '12, fsdasdasd, Bangkas Heights, City of Davao, Davao Del Sur, Davao Region', 49.00, 49.00, 1, 'delivered', '2025-11-22 20:56:36', '2025-11-22 20:56:53', '2025-11-22 20:56:55', NULL, '2025-11-22 20:55:40'),
(6, 7, NULL, 'fsdfsdfsdfsdf, fdsdfsdfsd, Maybula, Tulunan, Cotabato, SOCCSKSARGEN', '12, fsdasdasd, Bangkas Heights, City of Davao, Davao Del Sur, Davao Region', 49.00, 0.00, 0, NULL, NULL, NULL, NULL, NULL, '2025-11-23 01:17:34'),
(7, 8, NULL, '12, asdasdasdad, New Cebu, Lambayong, Sultan Kudarat, SOCCSKSARGEN, 4235', '45345345345, 5345353, Lourmah, Mahayag, Zamboanga Del Sur, Zamboanga Peninsula', 49.00, 0.00, 0, NULL, NULL, NULL, NULL, NULL, '2025-11-23 01:25:51'),
(8, 9, NULL, '12, asdasdasdad, New Cebu, Lambayong, Sultan Kudarat, SOCCSKSARGEN, 4235', '12, fsdasdasd, Bangkas Heights, City of Davao, Davao Del Sur, Davao Region', 49.00, 0.00, 0, NULL, NULL, NULL, NULL, NULL, '2025-11-23 01:53:04');

-- --------------------------------------------------------

--
-- Table structure for table `favorites`
--

CREATE TABLE `favorites` (
  `favorite_id` int(11) NOT NULL,
  `buyer_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `added_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `messages`
--

CREATE TABLE `messages` (
  `message_id` int(11) NOT NULL,
  `conversation_id` int(11) NOT NULL,
  `sender_id` int(11) NOT NULL,
  `sender_type` enum('buyer','seller','rider') NOT NULL,
  `message_text` text NOT NULL,
  `is_read` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `messages`
--

INSERT INTO `messages` (`message_id`, `conversation_id`, `sender_id`, `sender_type`, `message_text`, `is_read`, `created_at`) VALUES
(2, 2, 8, 'buyer', 'hey', 1, '2025-11-14 05:38:39'),
(3, 2, 8, 'buyer', 'hehey', 1, '2025-11-14 05:38:55'),
(4, 2, 8, 'buyer', 'helos', 1, '2025-11-14 05:42:19'),
(5, 2, 8, 'buyer', 'whta thesad', 1, '2025-11-14 05:43:54'),
(6, 2, 8, 'buyer', 'bye byeeee', 1, '2025-11-14 05:46:27'),
(7, 2, 8, 'buyer', 'helooo', 1, '2025-11-14 07:04:30'),
(8, 2, 7, 'seller', 'taasdasdasd', 1, '2025-11-19 05:09:45'),
(9, 2, 8, 'buyer', 'gigigigagag', 1, '2025-11-19 05:10:17'),
(10, 3, 21, 'rider', 'Hi! I\'m your rider for Order #VEL-2025-0003 from Justine Mark Gahi\'s Shop. I\'ll keep you updated on your delivery.', 0, '2025-11-19 05:12:04'),
(11, 3, 8, 'buyer', 'heys', 1, '2025-11-19 05:12:20'),
(12, 2, 7, 'seller', 'bas', 1, '2025-11-19 05:16:36'),
(13, 2, 8, 'buyer', 'beybe', 1, '2025-11-26 04:57:30');

-- --------------------------------------------------------

--
-- Table structure for table `notifications`
--

CREATE TABLE `notifications` (
  `notification_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `title` varchar(255) NOT NULL,
  `message` text NOT NULL,
  `notification_type` enum('order','delivery','product','message','system') NOT NULL,
  `is_read` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `order_id` int(11) DEFAULT NULL,
  `product_names` text DEFAULT NULL,
  `product_images` text DEFAULT NULL,
  `order_total` decimal(10,2) DEFAULT NULL,
  `formatted_date` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `notifications`
--

INSERT INTO `notifications` (`notification_id`, `user_id`, `title`, `message`, `notification_type`, `is_read`, `created_at`, `updated_at`, `order_id`, `product_names`, `product_images`, `order_total`, `formatted_date`) VALUES
(2, 25, 'Order Shipped', 'Your order #VEL-2025-0002 is now on its way! Expected delivery in 2-3 business days.', 'delivery', 1, '2025-11-21 08:50:45', '2025-11-21 08:58:54', 2, '[\"Blouson Top\", \"Summer Overshirt\"]', '[\"static/uploads/products/20251116_135910_0_ATTF-WS142_V2.avif\", \"static/uploads/products/20251116_135107_2_HLSA-WS189_V2.webp\"]', 2549.00, 'November 21, 2025 at 04:50 PM'),
(3, 25, 'Order Delivered', 'Your order #VEL-2025-0002 has been delivered successfully!', 'delivery', 1, '2025-11-21 08:59:04', '2025-11-21 08:59:09', 2, '[\"Blouson Top\", \"Summer Overshirt\"]', '[\"static/uploads/products/20251116_135910_0_ATTF-WS142_V2.avif\", \"static/uploads/products/20251116_135107_2_HLSA-WS189_V2.webp\"]', 2549.00, 'November 21, 2025 at 04:59 PM'),
(4, 20, 'Order Shipped', 'Your order #VEL-2025-0003 is now on its way! Expected delivery in 2-3 business days.', 'delivery', 1, '2025-11-22 02:54:20', '2025-11-22 02:54:29', 3, '[\"Blouson Top\"]', '[\"static/uploads/products/20251116_135910_0_ATTF-WS142_V2.avif\"]', 400.00, 'November 22, 2025 at 10:54 AM'),
(5, 20, 'Order Delivered', 'Your order #VEL-2025-0003 has been delivered successfully!', 'delivery', 1, '2025-11-22 02:56:00', '2025-11-22 02:56:11', 3, '[\"Blouson Top\"]', '[\"static/uploads/products/20251116_135910_0_ATTF-WS142_V2.avif\"]', 400.00, 'November 22, 2025 at 10:56 AM'),
(9, 20, 'Order Delivered', 'Your order #VEL-2025-0004 has been delivered successfully!', 'delivery', 1, '2025-11-22 21:31:26', '2025-11-22 21:31:33', 5, '[\"Blouson Top\"]', '[\"static/uploads/products/20251116_135910_0_ATTF-WS142_V2.avif\"]', 549.00, 'November 23, 2025 at 05:31 AM'),
(13, 19, '⛔ Account Suspended', 'Your account has been suspended for 2 weeks. Reason: dasdasd. You will not be able to access your account during this period. Please review our terms of service and community guidelines.', '', 0, '2025-11-29 10:09:23', '2025-11-29 10:09:23', NULL, NULL, NULL, NULL, 'November 29, 2025 at 06:09 PM'),
(14, 19, '⛔ Account Suspended', 'Your account has been suspended for 2 weeks. Reason: asdasd. You will not be able to access your account during this period. Please review our terms of service and community guidelines.', '', 0, '2025-11-29 10:20:56', '2025-11-29 10:20:56', NULL, NULL, NULL, NULL, 'November 29, 2025 at 06:20 PM'),
(15, 19, '⛔ Account Suspended', 'Your account has been suspended for 2 weeks. Reason: asdasdasd. You will not be able to access your account during this period. Please review our terms of service and community guidelines.', '', 0, '2025-11-29 10:23:33', '2025-11-29 10:23:33', NULL, NULL, NULL, NULL, 'November 29, 2025 at 06:23 PM');

-- --------------------------------------------------------

--
-- Table structure for table `orders`
--

CREATE TABLE `orders` (
  `order_id` int(11) NOT NULL,
  `order_number` varchar(50) NOT NULL,
  `buyer_id` int(11) NOT NULL,
  `seller_id` int(11) NOT NULL,
  `address_id` int(11) NOT NULL,
  `subtotal` decimal(10,2) NOT NULL,
  `shipping_fee` decimal(10,2) DEFAULT 0.00,
  `discount_amount` decimal(10,2) DEFAULT 0.00,
  `total_amount` decimal(10,2) NOT NULL,
  `commission_amount` decimal(10,2) DEFAULT 0.00,
  `voucher_id` int(11) DEFAULT NULL,
  `order_status` enum('pending','in_transit','delivered','cancelled') DEFAULT 'pending',
  `order_received` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `orders`
--

INSERT INTO `orders` (`order_id`, `order_number`, `buyer_id`, `seller_id`, `address_id`, `subtotal`, `shipping_fee`, `discount_amount`, `total_amount`, `commission_amount`, `voucher_id`, `order_status`, `order_received`, `created_at`, `updated_at`) VALUES
(1, 'VEL-2025-0001', 8, 7, 15, 5000.00, 0.00, 0.00, 5250.00, 250.00, NULL, 'delivered', 1, '2025-11-10 06:01:35', '2025-11-22 03:31:24'),
(2, 'VEL-2025-0002', 10, 7, 20, 2500.00, 49.00, 0.00, 2549.00, 125.00, NULL, 'delivered', 1, '2025-11-21 08:42:56', '2025-11-21 08:59:16'),
(3, 'VEL-2025-0003', 8, 7, 15, 500.00, 0.00, 100.00, 400.00, 25.00, NULL, 'delivered', 1, '2025-11-22 01:53:19', '2025-11-22 02:58:57'),
(5, 'VEL-2025-0004', 8, 7, 15, 500.00, 49.00, 0.00, 549.00, 25.00, NULL, 'delivered', 1, '2025-11-22 20:38:00', '2025-11-22 21:31:57'),
(6, 'VEL-2025-0005', 8, 7, 15, 1000.00, 0.00, 0.00, 1000.00, 50.00, 10, 'delivered', 1, '2025-11-22 20:55:40', '2025-11-22 20:57:20'),
(7, 'VEL-2025-0006', 8, 8, 15, 12300.00, 49.00, 3690.00, 8659.00, 615.00, 4, 'pending', 0, '2025-11-23 01:17:34', '2025-11-23 01:17:34'),
(8, 'VEL-2025-0007', 10, 7, 20, 1000.00, 49.00, 300.00, 749.00, 50.00, 4, 'pending', 0, '2025-11-23 01:25:51', '2025-11-23 01:25:51'),
(9, 'VEL-2025-0008', 8, 7, 15, 49500.00, 49.00, 0.00, 49549.00, 2475.00, NULL, 'pending', 0, '2025-11-23 01:53:04', '2025-11-23 01:53:04');

-- --------------------------------------------------------

--
-- Table structure for table `order_items`
--

CREATE TABLE `order_items` (
  `order_item_id` int(11) NOT NULL,
  `order_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `product_name` varchar(255) NOT NULL,
  `materials` text DEFAULT NULL,
  `variant_color` varchar(50) DEFAULT NULL,
  `variant_size` varchar(20) DEFAULT NULL,
  `quantity` int(11) NOT NULL,
  `unit_price` decimal(10,2) NOT NULL,
  `subtotal` decimal(10,2) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `order_items`
--

INSERT INTO `order_items` (`order_item_id`, `order_id`, `product_id`, `product_name`, `materials`, `variant_color`, `variant_size`, `quantity`, `unit_price`, `subtotal`, `created_at`) VALUES
(1, 1, 42, 'Blouson Top', '100% cotton\r\n\r\nMade in Italy\r\n\r\nHand wash\r\n\r\nFront button closure\r\n\r\nAsymmetrical hem and button cuffs\r\n\r\nHeavyweight denim fabric with front logo detailing\r\n', 'Gallery', 'L', 5, 500.00, 2500.00, '2025-11-21 06:01:35'),
(2, 1, 41, 'Summer Overshirt', '•	100% cotton\r\n•	Hand wash\r\n•	Front button closures\r\n•	Buttoned cuffs\r\n•	Poplin fabric with crochet embroidered detail\r\n•	Made in China\r\n•	Our Style No. HLSA-WS189\r\n•	Manufacturer Style No. HES10008 U25\r\n•	Model is wearing size XS. [View detailed measurements of this item.]\r\n', 'Bon Jour', 'S', 5, 500.00, 2500.00, '2025-11-21 06:01:35'),
(3, 2, 42, 'Blouson Top', '100% cotton\r\n\r\nMade in Italy\r\n\r\nHand wash\r\n\r\nFront button closure\r\n\r\nAsymmetrical hem and button cuffs\r\n\r\nHeavyweight denim fabric with front logo detailing\r\n', 'Gallery', 'M', 3, 500.00, 1500.00, '2025-11-21 08:42:56'),
(4, 2, 41, 'Summer Overshirt', '•	100% cotton\r\n•	Hand wash\r\n•	Front button closures\r\n•	Buttoned cuffs\r\n•	Poplin fabric with crochet embroidered detail\r\n•	Made in China\r\n•	Our Style No. HLSA-WS189\r\n•	Manufacturer Style No. HES10008 U25\r\n•	Model is wearing size XS. [View detailed measurements of this item.]\r\n', 'Bon Jour', 'XS', 2, 500.00, 1000.00, '2025-11-21 08:42:56'),
(5, 3, 42, 'Blouson Top', '100% cotton\r\n\r\nMade in Italy\r\n\r\nHand wash\r\n\r\nFront button closure\r\n\r\nAsymmetrical hem and button cuffs\r\n\r\nHeavyweight denim fabric with front logo detailing\r\n', 'Gallery', 'S', 1, 500.00, 500.00, '2025-11-22 01:53:19'),
(6, 5, 42, 'Blouson Top', 'potek', 'Gallery', 'XS', 1, 500.00, 500.00, '2025-11-22 20:38:00'),
(7, 6, 42, 'Blouson Top', 'potek', 'Gallery', 'S', 2, 500.00, 1000.00, '2025-11-22 20:55:40'),
(8, 7, 51, 'barongsss', 'asdasdasdasdasd', 'Givry', 'XS', 100, 123.00, 12300.00, '2025-11-23 01:17:34'),
(9, 8, 41, 'Summer Overshirt', '100% cotton', 'Bon Jour', 'L', 2, 500.00, 1000.00, '2025-11-23 01:25:51'),
(10, 9, 42, 'Blouson Top', 'potek', 'Gallery', 'XS', 99, 500.00, 49500.00, '2025-11-23 01:53:04');

-- --------------------------------------------------------

--
-- Table structure for table `products`
--

CREATE TABLE `products` (
  `product_id` int(11) NOT NULL,
  `seller_id` int(11) NOT NULL,
  `product_name` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `materials` text DEFAULT NULL,
  `SDG` enum('handmade','biodegradable','both') DEFAULT NULL,
  `price` decimal(10,2) NOT NULL,
  `category` varchar(100) NOT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `views_count` int(11) DEFAULT 0,
  `rating` decimal(3,2) DEFAULT 0.00,
  `total_reviews` int(11) DEFAULT 0,
  `total_sold` int(11) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `products`
--

INSERT INTO `products` (`product_id`, `seller_id`, `product_name`, `description`, `materials`, `SDG`, `price`, `category`, `is_active`, `views_count`, `rating`, `total_reviews`, `total_sold`, `created_at`, `updated_at`) VALUES
(41, 7, 'Summer Overshirt', 'The Summer Overshirt With Vintage Swiss Embroidery', '100% cotton', 'both', 500.00, 'tops', 1, 59, 5.00, 2, 11, '2025-11-03 05:51:07', '2025-11-29 08:58:00'),
(42, 7, 'Blouson Top', 'Our Style No. ATTIF-WS142\r\n\r\nManufacturer Style No. 250WCB0088 - DDD088SS - 024\r\n\r\nModel is wearing size 38. View detailed measurements of this item.\r\n', 'potek ihhiihihsdOur Style No. ATTIF-WS142\r\n\r\nManufacturer Style No. 250WCB0088 - DDD088SS - 024\r\n\r\nModel is wearing size 38. View detailed measurements of this item.\r\nSAD\r\nDSADASD\r\n', 'both', 3423435.00, 'tops', 1, 73, 5.00, 2, 121, '2025-11-16 05:59:10', '2025-11-29 09:26:46'),
(51, 8, 'barongsss', 'sdasdasdasd', 'asdasdasdasdasd', 'both', 123.00, 'tops', 1, 10, 0.00, 0, 100, '2025-11-22 18:07:52', '2025-11-29 08:58:02'),
(52, 7, 'asdas', 'dasd', 'asdad', 'biodegradable', 23.00, 'dresses', 1, 0, 0.00, 0, 0, '2025-11-28 09:28:15', '2025-11-28 09:28:15');

-- --------------------------------------------------------

--
-- Table structure for table `product_colors`
--
-- Error reading structure for table velare_ecommerce.product_colors: #1932 - Table &#039;velare_ecommerce.product_colors&#039; doesn&#039;t exist in engine
-- Error reading data for table velare_ecommerce.product_colors: #1064 - You have an error in your SQL syntax; check the manual that corresponds to your MariaDB server version for the right syntax to use near &#039;FROM `velare_ecommerce`.`product_colors`&#039; at line 1

-- --------------------------------------------------------

--
-- Table structure for table `product_images`
--

CREATE TABLE `product_images` (
  `image_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `variant_id` int(11) DEFAULT NULL,
  `image_url` varchar(255) NOT NULL,
  `is_primary` tinyint(1) DEFAULT 0,
  `display_order` int(11) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `product_images`
--

INSERT INTO `product_images` (`image_id`, `product_id`, `variant_id`, `image_url`, `is_primary`, `display_order`, `created_at`) VALUES
(129, 41, 106, 'static/uploads/products/20251116_135107_0_HLSA-WS189_V4.avif', 0, 2, '2025-11-16 05:51:07'),
(130, 41, 106, 'static/uploads/products/20251116_135107_1_HLSA-WS189_V3.webp', 0, 3, '2025-11-16 05:51:07'),
(131, 41, 106, 'static/uploads/products/20251116_135107_2_HLSA-WS189_V2.webp', 1, 0, '2025-11-16 05:51:07'),
(132, 41, 106, 'static/uploads/products/20251116_135107_3_HLSA-WS189_V5.avif', 0, 1, '2025-11-16 05:51:07'),
(133, 41, 106, 'static/uploads/products/20251116_135107_4_HLSA-WS189_V1.webp', 0, 4, '2025-11-16 05:51:07'),
(134, 42, 110, 'static/uploads/products/20251116_135910_0_ATTF-WS142_V2.avif', 1, 0, '2025-11-16 05:59:10'),
(135, 42, 110, 'static/uploads/products/20251116_135910_1_ATTF-WS142_V5.avif', 0, 1, '2025-11-16 05:59:10'),
(136, 42, 110, 'static/uploads/products/20251116_135910_2_ATTF-WS142_V1.avif', 0, 2, '2025-11-16 05:59:10'),
(137, 42, 110, 'static/uploads/products/20251116_135910_3_ATTF-WS142_V3.avif', 0, 3, '2025-11-16 05:59:10'),
(138, 42, 110, 'static/uploads/products/20251116_135910_4_ATTF-WS142_V4.avif', 0, 4, '2025-11-16 05:59:10'),
(151, 51, 128, 'static/uploads/products/20251123_020752_0_barong_1.jpg', 1, 0, '2025-11-22 18:07:52'),
(152, 51, 128, 'static/uploads/products/20251123_020752_1_barong_4.jpg', 0, 1, '2025-11-22 18:07:52'),
(153, 51, 128, 'static/uploads/products/20251123_020752_2_barong2.jpg', 0, 2, '2025-11-22 18:07:52'),
(154, 51, 128, 'static/uploads/products/20251123_020752_3_barong_5.gif', 0, 3, '2025-11-22 18:07:52'),
(155, 51, 128, 'static/uploads/products/20251123_020752_4_barong_3.jpg', 0, 4, '2025-11-22 18:07:52'),
(156, 51, 129, 'static/uploads/products/20251123_020752_5_stampita_3.jpg', 0, 5, '2025-11-22 18:07:52'),
(157, 51, 129, 'static/uploads/products/20251123_020752_6_stampita_4.jpg', 0, 6, '2025-11-22 18:07:52'),
(158, 51, 129, 'static/uploads/products/20251123_020752_7_stampita_1.jpg', 0, 7, '2025-11-22 18:07:52'),
(159, 51, 129, 'static/uploads/products/20251123_020752_8_stampita_2.JPG', 0, 8, '2025-11-22 18:07:52'),
(160, 51, 129, 'static/uploads/products/20251123_020752_9_life.webp', 0, 9, '2025-11-22 18:07:52'),
(161, 52, 130, 'static/uploads/products/20251128_172815_0_sampleimage4.webp', 1, 0, '2025-11-28 09:28:15');

-- --------------------------------------------------------

--
-- Table structure for table `product_reviews`
--

CREATE TABLE `product_reviews` (
  `review_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `buyer_id` int(11) NOT NULL,
  `order_id` int(11) NOT NULL,
  `rating` int(11) NOT NULL CHECK (`rating` >= 1 and `rating` <= 5),
  `review_text` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `product_reviews`
--

INSERT INTO `product_reviews` (`review_id`, `product_id`, `buyer_id`, `order_id`, `rating`, `review_text`, `created_at`) VALUES
(2, 42, 8, 1, 5, 'Nice Product!!!', '2025-11-21 08:04:33'),
(3, 41, 8, 1, 5, 'Super Beautiful!!!!', '2025-11-21 08:04:33'),
(4, 42, 10, 2, 5, 'WOW!!!', '2025-11-21 08:59:40'),
(5, 41, 10, 2, 5, 'AMAZINGGG EARTHHH!!!', '2025-11-21 08:59:40');

--
-- Triggers `product_reviews`
--
DELIMITER $$
CREATE TRIGGER `update_product_rating_after_review` AFTER INSERT ON `product_reviews` FOR EACH ROW BEGIN
    UPDATE products p
    SET 
        rating = (SELECT AVG(rating) FROM product_reviews WHERE product_id = NEW.product_id),
        total_reviews = (SELECT COUNT(*) FROM product_reviews WHERE product_id = NEW.product_id)
    WHERE product_id = NEW.product_id;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_seller_rating_after_review` AFTER INSERT ON `product_reviews` FOR EACH ROW BEGIN
    UPDATE sellers s
    SET rating = (
        SELECT AVG(pr.rating) 
        FROM product_reviews pr
        JOIN products p ON pr.product_id = p.product_id
        WHERE p.seller_id = (SELECT seller_id FROM products WHERE product_id = NEW.product_id)
    )
    WHERE seller_id = (SELECT seller_id FROM products WHERE product_id = NEW.product_id);
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `product_variants`
--

CREATE TABLE `product_variants` (
  `variant_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `color` varchar(50) DEFAULT NULL,
  `hex_code` varchar(7) DEFAULT NULL,
  `size` varchar(20) DEFAULT NULL,
  `stock_quantity` int(11) DEFAULT 0,
  `image_url` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `product_variants`
--

INSERT INTO `product_variants` (`variant_id`, `product_id`, `color`, `hex_code`, `size`, `stock_quantity`, `image_url`, `created_at`) VALUES
(106, 41, 'Bon Jour', '#ece7eb', 'XS', 0, 'static/uploads/products/20251116_135107_2_HLSA-WS189_V2.webp', '2025-11-16 05:51:07'),
(107, 41, 'Bon Jour', '#ece7eb', 'S', 93, 'static/uploads/products/20251116_135107_0_HLSA-WS189_V4.avif', '2025-11-16 05:51:07'),
(108, 41, 'Bon Jour', '#ece7eb', 'M', 100, 'static/uploads/products/20251116_135107_0_HLSA-WS189_V4.avif', '2025-11-16 05:51:07'),
(109, 41, 'Bon Jour', '#ece7eb', 'L', 98, 'static/uploads/products/20251116_135107_0_HLSA-WS189_V4.avif', '2025-11-16 05:51:07'),
(110, 42, 'Gallery', '#ededed', 'XS', 0, 'static/uploads/products/20251116_135910_0_ATTF-WS142_V2.avif', '2025-11-16 05:59:10'),
(111, 42, 'Gallery', '#ededed', 'S', 97, 'static/uploads/products/20251116_135910_0_ATTF-WS142_V2.avif', '2025-11-16 05:59:10'),
(112, 42, 'Gallery', '#ededed', 'M', 90, 'static/uploads/products/20251116_135910_0_ATTF-WS142_V2.avif', '2025-11-16 05:59:10'),
(113, 42, 'Gallery', '#ededed', 'XXL', 99, 'static/uploads/products/20251116_135910_0_ATTF-WS142_V2.avif', '2025-11-16 05:59:10'),
(114, 42, 'Gallery', '#ededed', 'L', 99993, 'static/uploads/products/20251116_135910_0_ATTF-WS142_V2.avif', '2025-11-16 05:59:10'),
(128, 51, 'Givry', '#f8e5c7', 'XS', 0, 'static/uploads/products/20251123_020752_0_barong_1.jpg', '2025-11-22 18:07:52'),
(129, 51, 'Blue Bell', '#8b91c4', 'XXL', 200, 'static/uploads/products/20251123_020752_5_stampita_3.jpg', '2025-11-22 18:07:52'),
(130, 52, 'Mine Shaft', '#2f2828', 'S', 1, 'static/uploads/products/20251128_172815_0_sampleimage4.webp', '2025-11-28 09:28:15');

-- --------------------------------------------------------

--
-- Table structure for table `review_images`
--

CREATE TABLE `review_images` (
  `review_image_id` int(11) NOT NULL,
  `review_id` int(11) NOT NULL,
  `image_url` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `riders`
--

CREATE TABLE `riders` (
  `rider_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `first_name` varchar(100) NOT NULL,
  `last_name` varchar(100) NOT NULL,
  `phone_number` varchar(20) NOT NULL,
  `profile_image` varchar(255) DEFAULT NULL,
  `vehicle_type` varchar(50) DEFAULT NULL,
  `id_type` varchar(50) DEFAULT NULL,
  `id_file_path` varchar(255) DEFAULT NULL,
  `rating` decimal(3,2) DEFAULT 0.00,
  `total_earnings` decimal(10,2) DEFAULT 0.00,
  `status` enum('available','busy','offline') DEFAULT 'offline',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `orcr_file_path` varchar(255) DEFAULT NULL,
  `driver_license_file_path` varchar(255) DEFAULT NULL,
  `plate_number` varchar(10) DEFAULT NULL,
  `available_balance` decimal(10,2) DEFAULT 0.00 COMMENT 'Available balance for withdrawal',
  `account_status` varchar(20) DEFAULT 'active',
  `suspension_end` datetime DEFAULT NULL,
  `suspension_reason` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `riders`
--

INSERT INTO `riders` (`rider_id`, `user_id`, `first_name`, `last_name`, `phone_number`, `profile_image`, `vehicle_type`, `id_type`, `id_file_path`, `rating`, `total_earnings`, `status`, `created_at`, `orcr_file_path`, `driver_license_file_path`, `plate_number`, `available_balance`, `account_status`, `suspension_end`, `suspension_reason`) VALUES
(4, 21, 're', 're', '09413142325', 'uploads/profiles/rider_21_search.png', 'Motorcycle', 'national_id', '/static/uploads/ids/rider_rere_gmail.com_Screenshot_2025-10-24_105648.png', 0.00, 196.00, 'available', '2025-10-29 12:30:52', '/static/uploads/rider_orcr/user_4/orcr_1764405871111_sampleimage4.webp', '/static/uploads/rider_dl/user_4/driver_license_1764405871120_400029166_658688353118621_2242446653820573432_n.jpg', 'DSA1232', 0.00, 'active', NULL, NULL),
(6, 26, 'Symon', 'Beato', '09423423434', NULL, 'tricycle', NULL, NULL, 0.00, 0.00, 'available', '2025-11-19 05:29:06', '/static/uploads/rider_orcr/user_6/orcr_rider_orcr_symonkiel01_gmail.com_barong_1.jpg', '/static/uploads/rider_dl/user_6/driver_license_rider_dl_symonkiel01_gmail.com_barong_3.jpg', 'ASD ASDASD', 0.00, 'active', NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `rider_withdrawals`
--

CREATE TABLE `rider_withdrawals` (
  `withdrawal_id` int(11) NOT NULL,
  `rider_id` int(11) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `withdrawal_method` varchar(50) DEFAULT 'Cash',
  `status` enum('pending','completed','rejected','cancelled') DEFAULT 'pending',
  `requested_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `processed_at` timestamp NULL DEFAULT NULL,
  `notes` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `rider_withdrawals`
--

INSERT INTO `rider_withdrawals` (`withdrawal_id`, `rider_id`, `amount`, `withdrawal_method`, `status`, `requested_at`, `processed_at`, `notes`) VALUES
(1, 4, 100.00, 'Bank Transfer', 'completed', '2025-11-22 20:08:13', '2025-11-22 22:02:46', ''),
(10, 4, 100.00, 'GCash', 'rejected', '2025-11-23 01:09:09', '2025-11-23 01:10:06', '\nRejection reason: '),
(11, 4, 100.00, 'Bank Transfer', 'rejected', '2025-11-23 01:11:15', '2025-11-23 01:11:34', '\nRejection reason: ');

-- --------------------------------------------------------

--
-- Table structure for table `sellers`
--

CREATE TABLE `sellers` (
  `seller_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `first_name` varchar(100) DEFAULT NULL,
  `last_name` varchar(100) DEFAULT NULL,
  `shop_name` varchar(255) NOT NULL,
  `shop_description` text DEFAULT NULL,
  `shop_logo` varchar(255) DEFAULT NULL,
  `phone_number` varchar(20) DEFAULT NULL,
  `id_type` varchar(50) DEFAULT NULL,
  `rating` decimal(3,2) DEFAULT 0.00,
  `total_sales` decimal(12,2) DEFAULT 0.00,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `id_file_path` varchar(255) DEFAULT NULL,
  `business_permit_file_path` varchar(255) DEFAULT NULL,
  `account_status` varchar(20) DEFAULT 'active',
  `suspension_end` datetime DEFAULT NULL,
  `suspension_reason` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `sellers`
--

INSERT INTO `sellers` (`seller_id`, `user_id`, `first_name`, `last_name`, `shop_name`, `shop_description`, `shop_logo`, `phone_number`, `id_type`, `rating`, `total_sales`, `created_at`, `id_file_path`, `business_permit_file_path`, `account_status`, `suspension_end`, `suspension_reason`) VALUES
(7, 19, 'Justine Mark', 'Gahi', 'Justine Mark Gahi\'s Shop', 'heloos helloos\r\n', 'uploads/shop_logos/seller_7_1763789601117_IOT_Smart_Home.png', '09124312313', 'sss', 5.00, 0.00, '2025-10-29 10:04:39', '/static/uploads/seller_ids/user_7/id_id_seller_7_1764213732965_lines.png', '/static/uploads/seller_permits/user_7/business_permit_permit_seller_7_1764213732971_search.png', 'suspended', '2025-12-13 18:23:33', 'asdasdasd'),
(8, 24, 'mark', 'gahi', 'mark gahi\'s Shop', 'Heylowsss', 'uploads/shop_logos/seller_8_1764290792028_sampleimage4.webp', '09456456456', 'sss', 0.00, 0.00, '2025-11-17 09:46:45', '/static/uploads/seller_ids/user_8/id_1764290877569_400029166_658688353118621_2242446653820573432_n.jpg', '/static/uploads/seller_permits/user_8/business_permit_1764290877581_399887839_883681432893590_4657680985446672628_n.jpg', 'active', NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `seller_vouchers`
--

CREATE TABLE `seller_vouchers` (
  `seller_voucher_id` int(11) NOT NULL,
  `seller_id` int(11) NOT NULL,
  `voucher_id` int(11) NOT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `selected_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `seller_vouchers`
--

INSERT INTO `seller_vouchers` (`seller_voucher_id`, `seller_id`, `voucher_id`, `is_active`, `selected_at`) VALUES
(1, 7, 10, 1, '2025-11-22 16:41:52'),
(4, 7, 4, 1, '2025-11-22 16:42:58'),
(5, 8, 10, 1, '2025-11-22 18:08:07'),
(6, 8, 4, 1, '2025-11-22 18:08:11');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `user_id` int(11) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `user_type` enum('buyer','seller','rider','admin') NOT NULL,
  `status` enum('active','pending','suspended','banned','rejected') DEFAULT 'pending',
  `reset_token` varchar(255) DEFAULT NULL,
  `reset_token_expiry` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `last_login` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `email`, `password`, `user_type`, `status`, `reset_token`, `reset_token_expiry`, `created_at`, `last_login`) VALUES
(1, 'admin@velare.com', 'admin123', 'admin', 'active', NULL, NULL, '2025-10-21 10:31:46', '2025-11-29 09:31:07'),
(19, 'justinemarkgahi@gmail.com', 'Qwerty12', 'seller', 'active', NULL, NULL, '2025-10-29 10:04:39', '2025-11-29 10:23:25'),
(20, 'jejemon@gmail.com', 'Qwerty12', 'buyer', 'active', NULL, NULL, '2025-10-29 12:21:33', '2025-11-29 08:57:44'),
(21, 'rere@gmail.com', 'Qwerty12', 'rider', 'active', NULL, NULL, '2025-10-29 12:30:52', '2025-11-29 07:34:32'),
(22, 'heylow@gmail.com', 'Qwerty12', 'buyer', 'pending', NULL, NULL, '2025-11-17 01:34:23', NULL),
(24, 'markjustinegahi@gmail.com', 'Qwerty12', 'seller', 'active', NULL, NULL, '2025-11-17 09:46:45', '2025-11-28 00:45:35'),
(25, 'jakemagbuhosjaqueca@gmail.com', 'Qwerty12', 'buyer', 'active', NULL, NULL, '2025-11-19 05:22:54', '2025-11-23 01:53:24'),
(26, 'symonkiel01@gmail.com', 'Qwerty12', 'rider', 'active', NULL, NULL, '2025-11-19 05:29:06', '2025-11-19 05:38:28');

-- --------------------------------------------------------

--
-- Table structure for table `user_reports`
--

CREATE TABLE `user_reports` (
  `report_id` int(11) NOT NULL,
  `reporter_id` int(11) NOT NULL,
  `reporter_type` enum('buyer','seller','rider') NOT NULL,
  `reported_user_id` int(11) NOT NULL,
  `reported_user_type` enum('buyer','seller','rider') NOT NULL,
  `report_category` enum('fraud','harassment','poor_service','fake_product','late_delivery','rude_behavior','other') NOT NULL,
  `report_reason` text NOT NULL,
  `order_id` int(11) DEFAULT NULL,
  `delivery_id` int(11) DEFAULT NULL,
  `evidence_image` varchar(255) DEFAULT NULL,
  `status` enum('pending','under_review','resolved','dismissed') DEFAULT 'pending',
  `admin_notes` text DEFAULT NULL,
  `admin_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `resolved_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `user_reports`
--

INSERT INTO `user_reports` (`report_id`, `reporter_id`, `reporter_type`, `reported_user_id`, `reported_user_type`, `report_category`, `report_reason`, `order_id`, `delivery_id`, `evidence_image`, `status`, `admin_notes`, `admin_id`, `created_at`, `updated_at`, `resolved_at`) VALUES
(1, 20, 'buyer', 19, 'seller', 'fake_product', 'Panget', 9, NULL, 'static/uploads/reports/report_20251128_194105_lines.png', 'under_review', '', 1, '2025-11-28 11:41:05', '2025-11-28 11:45:38', NULL);

-- --------------------------------------------------------

--
-- Stand-in structure for view `view_product_performance`
-- (See below for the actual view)
--
CREATE TABLE `view_product_performance` (
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `view_sales_report`
-- (See below for the actual view)
--
CREATE TABLE `view_sales_report` (
`order_id` int(11)
,`order_number` varchar(50)
,`order_date` timestamp
,`buyer_name` varchar(201)
,`shop_name` varchar(255)
,`total_amount` decimal(10,2)
,`commission_amount` decimal(10,2)
,`order_status` enum('pending','in_transit','delivered','cancelled')
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `view_user_reports`
-- (See below for the actual view)
--
CREATE TABLE `view_user_reports` (
`report_id` int(11)
,`reporter_type` enum('buyer','seller','rider')
,`reported_user_type` enum('buyer','seller','rider')
,`report_category` enum('fraud','harassment','poor_service','fake_product','late_delivery','rude_behavior','other')
,`report_reason` text
,`status` enum('pending','under_review','resolved','dismissed')
,`created_at` timestamp
,`order_id` int(11)
,`delivery_id` int(11)
);

-- --------------------------------------------------------

--
-- Table structure for table `vouchers`
--

CREATE TABLE `vouchers` (
  `voucher_id` int(11) NOT NULL,
  `voucher_code` varchar(50) NOT NULL,
  `voucher_name` varchar(255) NOT NULL,
  `voucher_type` enum('free_shipping','discount') NOT NULL,
  `discount_percent` int(11) DEFAULT 0,
  `description` text DEFAULT NULL,
  `restriction` varchar(255) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `start_date` timestamp NULL DEFAULT current_timestamp(),
  `end_date` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `vouchers`
--

INSERT INTO `vouchers` (`voucher_id`, `voucher_code`, `voucher_name`, `voucher_type`, `discount_percent`, `description`, `restriction`, `is_active`, `start_date`, `end_date`, `created_at`) VALUES
(4, 'SAVE30', '30% Discount', 'discount', 30, NULL, NULL, 1, '2025-11-21 16:00:00', '2025-11-29 16:00:00', '2025-11-22 14:57:28'),
(10, 'FREESHIP', '100% Free Shipping', 'free_shipping', 100, NULL, NULL, 1, '2025-11-22 16:00:00', '2025-11-29 16:00:00', '2025-11-22 16:26:30');

-- --------------------------------------------------------

--
-- Structure for view `view_product_performance`
--
DROP TABLE IF EXISTS `view_product_performance`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_product_performance`  AS SELECT `p`.`product_id` AS `product_id`, `p`.`product_name` AS `product_name`, `s`.`shop_name` AS `shop_name`, `p`.`category` AS `category`, `p`.`price` AS `price`, `p`.`stock_quantity` AS `stock_quantity`, `p`.`views_count` AS `views_count`, `p`.`rating` AS `rating`, `p`.`total_reviews` AS `total_reviews`, `p`.`total_sold` AS `total_sold`, `p`.`approval_status` AS `approval_status` FROM (`products` `p` join `sellers` `s` on(`p`.`seller_id` = `s`.`seller_id`)) ;

-- --------------------------------------------------------

--
-- Structure for view `view_sales_report`
--
DROP TABLE IF EXISTS `view_sales_report`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_sales_report`  AS SELECT `o`.`order_id` AS `order_id`, `o`.`order_number` AS `order_number`, `o`.`created_at` AS `order_date`, concat(`b`.`first_name`,' ',`b`.`last_name`) AS `buyer_name`, `s`.`shop_name` AS `shop_name`, `o`.`total_amount` AS `total_amount`, `o`.`commission_amount` AS `commission_amount`, `o`.`order_status` AS `order_status` FROM ((`orders` `o` join `buyers` `b` on(`o`.`buyer_id` = `b`.`buyer_id`)) join `sellers` `s` on(`o`.`seller_id` = `s`.`seller_id`)) ;

-- --------------------------------------------------------

--
-- Structure for view `view_user_reports`
--
DROP TABLE IF EXISTS `view_user_reports`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_user_reports`  AS SELECT `ur`.`report_id` AS `report_id`, `ur`.`reporter_type` AS `reporter_type`, `ur`.`reported_user_type` AS `reported_user_type`, `ur`.`report_category` AS `report_category`, `ur`.`report_reason` AS `report_reason`, `ur`.`status` AS `status`, `ur`.`created_at` AS `created_at`, `ur`.`order_id` AS `order_id`, `ur`.`delivery_id` AS `delivery_id` FROM `user_reports` AS `ur` ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `addresses`
--
ALTER TABLE `addresses`
  ADD PRIMARY KEY (`address_id`),
  ADD KEY `idx_user_type` (`user_type`),
  ADD KEY `idx_user_ref_id` (`user_ref_id`),
  ADD KEY `idx_is_default` (`is_default`);

--
-- Indexes for table `admins`
--
ALTER TABLE `admins`
  ADD PRIMARY KEY (`admin_id`),
  ADD UNIQUE KEY `user_id` (`user_id`);

--
-- Indexes for table `buyers`
--
ALTER TABLE `buyers`
  ADD PRIMARY KEY (`buyer_id`),
  ADD UNIQUE KEY `user_id` (`user_id`),
  ADD KEY `idx_buyers_account_status` (`account_status`);

--
-- Indexes for table `buyer_vouchers`
--
ALTER TABLE `buyer_vouchers`
  ADD PRIMARY KEY (`buyer_voucher_id`),
  ADD KEY `voucher_id` (`voucher_id`),
  ADD KEY `idx_buyer_id` (`buyer_id`);

--
-- Indexes for table `cart`
--
ALTER TABLE `cart`
  ADD PRIMARY KEY (`cart_id`),
  ADD KEY `product_id` (`product_id`),
  ADD KEY `variant_id` (`variant_id`),
  ADD KEY `idx_buyer_id` (`buyer_id`);

--
-- Indexes for table `conversations`
--
ALTER TABLE `conversations`
  ADD PRIMARY KEY (`conversation_id`),
  ADD UNIQUE KEY `unique_buyer_seller` (`buyer_id`,`seller_id`,`delivery_id`),
  ADD UNIQUE KEY `unique_buyer_rider_delivery` (`buyer_id`,`rider_id`,`delivery_id`),
  ADD KEY `idx_buyer_id` (`buyer_id`),
  ADD KEY `idx_seller_id` (`seller_id`),
  ADD KEY `rider_id` (`rider_id`),
  ADD KEY `delivery_id` (`delivery_id`);

--
-- Indexes for table `deliveries`
--
ALTER TABLE `deliveries`
  ADD PRIMARY KEY (`delivery_id`),
  ADD KEY `idx_order_id` (`order_id`),
  ADD KEY `idx_rider_id` (`rider_id`),
  ADD KEY `idx_status` (`status`);

--
-- Indexes for table `favorites`
--
ALTER TABLE `favorites`
  ADD PRIMARY KEY (`favorite_id`),
  ADD UNIQUE KEY `unique_favorite` (`buyer_id`,`product_id`),
  ADD KEY `product_id` (`product_id`),
  ADD KEY `idx_buyer_id` (`buyer_id`);

--
-- Indexes for table `messages`
--
ALTER TABLE `messages`
  ADD PRIMARY KEY (`message_id`),
  ADD KEY `sender_id` (`sender_id`),
  ADD KEY `idx_conversation_id` (`conversation_id`),
  ADD KEY `idx_is_read` (`is_read`);

--
-- Indexes for table `notifications`
--
ALTER TABLE `notifications`
  ADD PRIMARY KEY (`notification_id`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_is_read` (`is_read`),
  ADD KEY `idx_created_at` (`created_at`),
  ADD KEY `idx_user_read` (`user_id`,`is_read`),
  ADD KEY `idx_user_type` (`user_id`,`notification_type`),
  ADD KEY `idx_order_id` (`order_id`);

--
-- Indexes for table `orders`
--
ALTER TABLE `orders`
  ADD PRIMARY KEY (`order_id`),
  ADD UNIQUE KEY `order_number` (`order_number`),
  ADD KEY `address_id` (`address_id`),
  ADD KEY `voucher_id` (`voucher_id`),
  ADD KEY `idx_order_number` (`order_number`),
  ADD KEY `idx_buyer_id` (`buyer_id`),
  ADD KEY `idx_seller_id` (`seller_id`),
  ADD KEY `idx_order_status` (`order_status`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- Indexes for table `order_items`
--
ALTER TABLE `order_items`
  ADD PRIMARY KEY (`order_item_id`),
  ADD KEY `idx_order_id` (`order_id`),
  ADD KEY `idx_product_id` (`product_id`);

--
-- Indexes for table `products`
--
ALTER TABLE `products`
  ADD PRIMARY KEY (`product_id`),
  ADD KEY `idx_seller_id` (`seller_id`),
  ADD KEY `idx_category` (`category`),
  ADD KEY `idx_product_name` (`product_name`);

--
-- Indexes for table `product_images`
--
ALTER TABLE `product_images`
  ADD PRIMARY KEY (`image_id`),
  ADD KEY `idx_product_id` (`product_id`),
  ADD KEY `idx_variant_id` (`variant_id`);

--
-- Indexes for table `product_reviews`
--
ALTER TABLE `product_reviews`
  ADD PRIMARY KEY (`review_id`),
  ADD KEY `order_id` (`order_id`),
  ADD KEY `idx_product_id` (`product_id`),
  ADD KEY `idx_buyer_id` (`buyer_id`);

--
-- Indexes for table `product_variants`
--
ALTER TABLE `product_variants`
  ADD PRIMARY KEY (`variant_id`),
  ADD KEY `idx_product_id` (`product_id`),
  ADD KEY `idx_image_url` (`image_url`);

--
-- Indexes for table `review_images`
--
ALTER TABLE `review_images`
  ADD PRIMARY KEY (`review_image_id`),
  ADD KEY `idx_review_id` (`review_id`);

--
-- Indexes for table `riders`
--
ALTER TABLE `riders`
  ADD PRIMARY KEY (`rider_id`),
  ADD UNIQUE KEY `user_id` (`user_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_riders_account_status` (`account_status`);

--
-- Indexes for table `rider_withdrawals`
--
ALTER TABLE `rider_withdrawals`
  ADD PRIMARY KEY (`withdrawal_id`),
  ADD KEY `idx_rider_id` (`rider_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_requested_at` (`requested_at`);

--
-- Indexes for table `sellers`
--
ALTER TABLE `sellers`
  ADD PRIMARY KEY (`seller_id`),
  ADD UNIQUE KEY `user_id` (`user_id`),
  ADD KEY `idx_shop_name` (`shop_name`),
  ADD KEY `idx_sellers_account_status` (`account_status`);

--
-- Indexes for table `seller_vouchers`
--
ALTER TABLE `seller_vouchers`
  ADD PRIMARY KEY (`seller_voucher_id`),
  ADD UNIQUE KEY `unique_seller_voucher` (`seller_id`,`voucher_id`),
  ADD KEY `idx_seller_vouchers_seller_id` (`seller_id`),
  ADD KEY `idx_seller_vouchers_voucher_id` (`voucher_id`),
  ADD KEY `idx_seller_vouchers_active` (`is_active`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `idx_email` (`email`),
  ADD KEY `idx_user_type` (`user_type`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_reset_token` (`reset_token`);

--
-- Indexes for table `user_reports`
--
ALTER TABLE `user_reports`
  ADD PRIMARY KEY (`report_id`),
  ADD KEY `order_id` (`order_id`),
  ADD KEY `delivery_id` (`delivery_id`),
  ADD KEY `idx_reporter_id` (`reporter_id`),
  ADD KEY `idx_reported_user_id` (`reported_user_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_created_at` (`created_at`);

--
-- Indexes for table `vouchers`
--
ALTER TABLE `vouchers`
  ADD PRIMARY KEY (`voucher_id`),
  ADD UNIQUE KEY `voucher_code` (`voucher_code`),
  ADD KEY `idx_voucher_code` (`voucher_code`),
  ADD KEY `idx_is_active` (`is_active`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `addresses`
--
ALTER TABLE `addresses`
  MODIFY `address_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=27;

--
-- AUTO_INCREMENT for table `admins`
--
ALTER TABLE `admins`
  MODIFY `admin_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `buyers`
--
ALTER TABLE `buyers`
  MODIFY `buyer_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `buyer_vouchers`
--
ALTER TABLE `buyer_vouchers`
  MODIFY `buyer_voucher_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT for table `cart`
--
ALTER TABLE `cart`
  MODIFY `cart_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=33;

--
-- AUTO_INCREMENT for table `conversations`
--
ALTER TABLE `conversations`
  MODIFY `conversation_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `deliveries`
--
ALTER TABLE `deliveries`
  MODIFY `delivery_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `favorites`
--
ALTER TABLE `favorites`
  MODIFY `favorite_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `messages`
--
ALTER TABLE `messages`
  MODIFY `message_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT for table `notifications`
--
ALTER TABLE `notifications`
  MODIFY `notification_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT for table `orders`
--
ALTER TABLE `orders`
  MODIFY `order_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT for table `order_items`
--
ALTER TABLE `order_items`
  MODIFY `order_item_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `products`
--
ALTER TABLE `products`
  MODIFY `product_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=54;

--
-- AUTO_INCREMENT for table `product_images`
--
ALTER TABLE `product_images`
  MODIFY `image_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=163;

--
-- AUTO_INCREMENT for table `product_reviews`
--
ALTER TABLE `product_reviews`
  MODIFY `review_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `product_variants`
--
ALTER TABLE `product_variants`
  MODIFY `variant_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=132;

--
-- AUTO_INCREMENT for table `review_images`
--
ALTER TABLE `review_images`
  MODIFY `review_image_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `riders`
--
ALTER TABLE `riders`
  MODIFY `rider_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `rider_withdrawals`
--
ALTER TABLE `rider_withdrawals`
  MODIFY `withdrawal_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT for table `sellers`
--
ALTER TABLE `sellers`
  MODIFY `seller_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `seller_vouchers`
--
ALTER TABLE `seller_vouchers`
  MODIFY `seller_voucher_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=27;

--
-- AUTO_INCREMENT for table `user_reports`
--
ALTER TABLE `user_reports`
  MODIFY `report_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `vouchers`
--
ALTER TABLE `vouchers`
  MODIFY `voucher_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `admins`
--
ALTER TABLE `admins`
  ADD CONSTRAINT `admins_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `buyers`
--
ALTER TABLE `buyers`
  ADD CONSTRAINT `buyers_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `buyer_vouchers`
--
ALTER TABLE `buyer_vouchers`
  ADD CONSTRAINT `buyer_vouchers_ibfk_1` FOREIGN KEY (`buyer_id`) REFERENCES `buyers` (`buyer_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `buyer_vouchers_ibfk_2` FOREIGN KEY (`voucher_id`) REFERENCES `vouchers` (`voucher_id`) ON DELETE CASCADE;

--
-- Constraints for table `cart`
--
ALTER TABLE `cart`
  ADD CONSTRAINT `cart_ibfk_1` FOREIGN KEY (`buyer_id`) REFERENCES `buyers` (`buyer_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `cart_ibfk_2` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `cart_ibfk_3` FOREIGN KEY (`variant_id`) REFERENCES `product_variants` (`variant_id`) ON DELETE SET NULL;

--
-- Constraints for table `conversations`
--
ALTER TABLE `conversations`
  ADD CONSTRAINT `conversations_ibfk_1` FOREIGN KEY (`buyer_id`) REFERENCES `buyers` (`buyer_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `conversations_ibfk_2` FOREIGN KEY (`seller_id`) REFERENCES `sellers` (`seller_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `conversations_ibfk_3` FOREIGN KEY (`rider_id`) REFERENCES `riders` (`rider_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `conversations_ibfk_4` FOREIGN KEY (`delivery_id`) REFERENCES `deliveries` (`delivery_id`) ON DELETE CASCADE;

--
-- Constraints for table `deliveries`
--
ALTER TABLE `deliveries`
  ADD CONSTRAINT `deliveries_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `deliveries_ibfk_2` FOREIGN KEY (`rider_id`) REFERENCES `riders` (`rider_id`) ON DELETE SET NULL;

--
-- Constraints for table `favorites`
--
ALTER TABLE `favorites`
  ADD CONSTRAINT `favorites_ibfk_1` FOREIGN KEY (`buyer_id`) REFERENCES `buyers` (`buyer_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `favorites_ibfk_2` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE CASCADE;

--
-- Constraints for table `messages`
--
ALTER TABLE `messages`
  ADD CONSTRAINT `messages_ibfk_1` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`conversation_id`) ON DELETE CASCADE;

--
-- Constraints for table `notifications`
--
ALTER TABLE `notifications`
  ADD CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `notifications_ibfk_2` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`) ON DELETE SET NULL;

--
-- Constraints for table `orders`
--
ALTER TABLE `orders`
  ADD CONSTRAINT `orders_ibfk_1` FOREIGN KEY (`buyer_id`) REFERENCES `buyers` (`buyer_id`),
  ADD CONSTRAINT `orders_ibfk_2` FOREIGN KEY (`seller_id`) REFERENCES `sellers` (`seller_id`),
  ADD CONSTRAINT `orders_ibfk_3` FOREIGN KEY (`address_id`) REFERENCES `addresses` (`address_id`),
  ADD CONSTRAINT `orders_ibfk_4` FOREIGN KEY (`voucher_id`) REFERENCES `vouchers` (`voucher_id`) ON DELETE SET NULL;

--
-- Constraints for table `order_items`
--
ALTER TABLE `order_items`
  ADD CONSTRAINT `order_items_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `order_items_ibfk_2` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`);

--
-- Constraints for table `products`
--
ALTER TABLE `products`
  ADD CONSTRAINT `products_ibfk_1` FOREIGN KEY (`seller_id`) REFERENCES `sellers` (`seller_id`) ON DELETE CASCADE;

--
-- Constraints for table `product_images`
--
ALTER TABLE `product_images`
  ADD CONSTRAINT `fk_product_images_variant` FOREIGN KEY (`variant_id`) REFERENCES `product_variants` (`variant_id`) ON DELETE SET NULL,
  ADD CONSTRAINT `product_images_ibfk_1` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `product_images_ibfk_2` FOREIGN KEY (`variant_id`) REFERENCES `product_variants` (`variant_id`) ON DELETE SET NULL;

--
-- Constraints for table `product_reviews`
--
ALTER TABLE `product_reviews`
  ADD CONSTRAINT `product_reviews_ibfk_1` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `product_reviews_ibfk_2` FOREIGN KEY (`buyer_id`) REFERENCES `buyers` (`buyer_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `product_reviews_ibfk_3` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`) ON DELETE CASCADE;

--
-- Constraints for table `product_variants`
--
ALTER TABLE `product_variants`
  ADD CONSTRAINT `product_variants_ibfk_1` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE CASCADE;

--
-- Constraints for table `review_images`
--
ALTER TABLE `review_images`
  ADD CONSTRAINT `review_images_ibfk_1` FOREIGN KEY (`review_id`) REFERENCES `product_reviews` (`review_id`) ON DELETE CASCADE;

--
-- Constraints for table `riders`
--
ALTER TABLE `riders`
  ADD CONSTRAINT `riders_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `rider_withdrawals`
--
ALTER TABLE `rider_withdrawals`
  ADD CONSTRAINT `rider_withdrawals_ibfk_1` FOREIGN KEY (`rider_id`) REFERENCES `riders` (`rider_id`) ON DELETE CASCADE;

--
-- Constraints for table `sellers`
--
ALTER TABLE `sellers`
  ADD CONSTRAINT `sellers_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `seller_vouchers`
--
ALTER TABLE `seller_vouchers`
  ADD CONSTRAINT `seller_vouchers_ibfk_1` FOREIGN KEY (`seller_id`) REFERENCES `sellers` (`seller_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `seller_vouchers_ibfk_2` FOREIGN KEY (`voucher_id`) REFERENCES `vouchers` (`voucher_id`) ON DELETE CASCADE;

--
-- Constraints for table `user_reports`
--
ALTER TABLE `user_reports`
  ADD CONSTRAINT `user_reports_ibfk_1` FOREIGN KEY (`reporter_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `user_reports_ibfk_2` FOREIGN KEY (`reported_user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `user_reports_ibfk_3` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`) ON DELETE SET NULL,
  ADD CONSTRAINT `user_reports_ibfk_4` FOREIGN KEY (`delivery_id`) REFERENCES `deliveries` (`delivery_id`) ON DELETE SET NULL;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
